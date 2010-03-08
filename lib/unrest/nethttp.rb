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
    @@request_types = {
      :get => Net::HTTP::Get,
      :post => Net::HTTP::Post,
      :put => Net::HTTP::Put,
      :delete => Net::HTTP::Delete
    }

    def self.request_types
      @@request_types
    end

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

    def request(method, options = {})
      params = options[:params]
      rqtype = @@request_types[method] || raise(ArgumentError, "Unsupported method #{method}")

      path = options[:path]
      headers = build_request_headers(options[:headers])
      if !params.empty? &&  [:post, :put].include?(method)
        form_data = params
      else
        path = "#{path}?#{params_to_query(params)}"
      end

      rq = rqtype.new(path, headers)
      rq.form_data = form_data if form_data
      rq.body = options[:body] if options[:body]

      resp = http_request(rq)
      if block_given?
        yield resp
      else
        check_and_raise(resp)
      end
    end

    private
    def params_to_query(params)
      return '' if !params || params.empty?
      require 'cgi' unless defined?(CGI) && defined?(CGI::escape)
      params.map do |k, v|
        q = CGI.escape(k.to_s)
        q << '=' << CGI.escape(v.to_s) if v
        q
      end * '&'
    end

    # Makes request to remote service.
    def http_request(rq)
      logger.debug "#{rq.method.to_s.upcase} #{site.merge(:path => rq.path)}" if logger
      result = nil
      ms = 1000 * Benchmark.realtime { result = http.request(rq) }
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
        def success?
          exception.nil?
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
        Net::HTTP.new(@site.normalized_host, @site.inferred_port, @proxy.host, @proxy.port, @proxy.user, @proxy.password)
      else
        Net::HTTP.new(@site.normalized_host, @site.inferred_port)
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
      return http unless @site.normalized_scheme == 'https'

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
