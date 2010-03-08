require 'net/https'
require 'date'
require 'time'
require 'benchmark'
require 'stringio'
require 'unrest/connection'


module UnREST
  # Class to handle connections to remote web services.
  # This class is used by ActiveResource::Base to interface with REST
  # services.
  class NetHttpConnection < Connection

    attr_reader :proxy, :ssl_options

    # Set URI for remote service.
    def site=(site)
      @http = nil
      super
    end

    # Set the proxy for remote service.
    def proxy=(proxy)
      @http = nil
      @proxy = proxy.is_a?(URI) ? proxy : URI.parse(proxy)
    end

    # Set the number of seconds after which HTTP requests to the remote service should time out.
    def timeout=(timeout)
      @timeout = timeout
      configure_http(@http) if @http
    end

    # Hash of options applied to Net::HTTP instance when +site+ protocol is 'https'.
    def ssl_options=(opts={})
      @ssl_options = opts
      configure_http(@http) if @http
    end

    # Execute a GET request.
    # Used to get (find) resources.
    def get(path = nil, params = {}, headers = {}, &block)
      request(block, Net::HTTP::Get, path, params, headers)
    end

    # Execute a DELETE request (see HTTP protocol documentation if unfamiliar).
    # Used to delete resources.
    def delete(path, params = {}, headers = {}, &block)
      request(block, Net::HTTP::Delete, path, params, headers)
    end

    # Execute a PUT request (see HTTP protocol documentation if unfamiliar).
    # Used to update resources.
    def put(path, params = {}, body = '', headers = {}, &block)
      request(block, Net::HTTP::Put, path, body ? params : {}, headers) do |rq|
        if body
          rq.body = body
        else
          rq.form_data = params
        end
      end
    end

    # Execute a POST request.
    # Used to create new resources.
    def post(path, params = {}, body = nil, headers = {}, &block)
      request(block, Net::HTTP::Post, path, body ? params : {}, headers) do |rq|
        if body
          rq.body = body
        else
          rq.form_data = params
        end
      end
    end

    # Execute a HEAD request.
    # Used to obtain meta-information about resources, such as whether they exist and their size (via response headers).
    def head(path, params = {}, headers = {}, &block)
      request(block, Net::HTTP::Head, path, params, headers)
    end

    private
    def request(handler, rqtype, path, params, headers)
      query = params_to_query(params)
      rq = rqtype.new(query.empty? ? path : "#{path}?#{query}", build_request_headers(headers))
      yield rq if block_given?
      resp = http_request(rq)
      if handler
        handler.call(resp)
        resp
      else
        check_and_raise(resp)
      end
    end

    def params_to_query(params)
      require 'cgi' unless defined?(CGI) && defined?(CGI::escape)
      params.map do |k, v|
        q = CGI.escape(k.to_s)
        q << '=' << CGI.escape(v.to_s) if v
        q
      end * '&'
    end

    # Makes request to remote service.
    def http_request(rq)
      logger.debug "#{rq.method.to_s.upcase} #{site.merge(rq.path)}" if logger
      result = nil
      ms = 1000 * Benchmark.realtime { result = http.request(rq) }
      result = http.request(rq)
      logger.debug "--> %d %s (%d %.0fms)" % [result.code, result.message, result.body ? result.body.length : 0, ms] if logger
      augment_response(result)
    rescue Timeout::Error => e
      raise TimeoutError.new(e.message)
    rescue OpenSSL::SSL::SSLError => e
      raise SSLError.new(e.message)
    end

    def augment_response(response)
      class << response
        attr_accessor :exception
        alias headers to_hash
        def body_stream
          body && StringIO.new(body)
        end
      end
      handle_response(response)
    end

    # Creates new Net::HTTP instance for communication with
    # remote service and resources.
    def http
      @http ||= configure_http(new_http)
    end

    def new_http
      if @proxy
        Net::HTTP.new(@site.host, @site.port, @proxy.host, @proxy.port, @proxy.user, @proxy.password)
      else
        Net::HTTP.new(@site.host, @site.port)
      end
    end

    def configure_http(http)
      http = apply_ssl_options(http)

      # Net::HTTP timeouts default to 60 seconds.
      if @timeout
        http.open_timeout = @timeout
        http.read_timeout = @timeout
      end

      http
    end

    def apply_ssl_options(http)
      return http unless @site.is_a?(URI::HTTPS)

      http.use_ssl     = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      return http unless defined?(@ssl_options)

      http.ca_path     = @ssl_options[:ca_path] if @ssl_options[:ca_path]
      http.ca_file     = @ssl_options[:ca_file] if @ssl_options[:ca_file]

      http.cert        = @ssl_options[:cert] if @ssl_options[:cert]
      http.key         = @ssl_options[:key]  if @ssl_options[:key]

      http.cert_store  = @ssl_options[:cert_store]  if @ssl_options[:cert_store]
      http.ssl_timeout = @ssl_options[:ssl_timeout] if @ssl_options[:ssl_timeout]

      http.verify_mode     = @ssl_options[:verify_mode]     if @ssl_options[:verify_mode]
      http.verify_callback = @ssl_options[:verify_callback] if @ssl_options[:verify_callback]
      http.verify_depth    = @ssl_options[:verify_depth]    if @ssl_options[:verify_depth]

      http
    end
  end
end
