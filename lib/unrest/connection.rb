require 'net/https'
require 'date'
require 'time'
require 'uri'
require 'benchmark'
require 'unrest/exceptions'

module UnREST
  # Class to handle connections to remote web services.
  # This class is used by ActiveResource::Base to interface with REST
  # services.
  class Connection

    attr_reader :site, :user, :password, :timeout, :proxy, :ssl_options

    # The +site+ parameter is required and will set the +site+
    # attribute to the URI for the remote resource service.
    def initialize(site)
      raise ArgumentError, 'Missing site URI' unless site
      self.site = site
    end

    # Set URI for remote service.
    def site=(site)
      @http = nil

      @site = site.is_a?(URI) ? site : URI.parse(site)
      (@site = @site.dup).path = '' unless @site.path.empty?

      @user = URI.decode(@site.user) if @site.user
      @password = URI.decode(@site.password) if @site.password
    end

    # Set the proxy for remote service.
    def proxy=(proxy)
      @http = nil
      @proxy = proxy.is_a?(URI) ? proxy : URI.parse(proxy)
    end

    # Set the user for remote service.
    def user=(user)
      @user = user
    end

    # Set password for remote service.
    def password=(password)
      @password = password
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
    def get(path = nil, params = {}, headers = {})
      request(Net::HTTP::Get, path, params, headers)
    end

    # Execute a DELETE request (see HTTP protocol documentation if unfamiliar).
    # Used to delete resources.
    def delete(path, params = {}, headers = {})
      request(Net::HTTP::Delete, path, params, headers)
    end

    # Execute a PUT request (see HTTP protocol documentation if unfamiliar).
    # Used to update resources.
    def put(path, params = {}, body = '', headers = {})
      request(Net::HTTP::Put, path, body ? params : {}, headers) do |rq|
        if body
          rq.body = body
        else
          rq.form_data = params
        end
      end
    end

    # Execute a POST request.
    # Used to create new resources.
    def post(path, params = {}, body = nil, headers = {})
      request(Net::HTTP::Post, path, body ? params : {}, headers) do |rq|
        if body
          rq.body = body
        else
          rq.form_data = params
        end
      end
    end

    # Execute a HEAD request.
    # Used to obtain meta-information about resources, such as whether they exist and their size (via response headers).
    def head(path, params = {}, headers = {})
      request(Net::HTTP::Head, path, params, headers)
    end


    private
    def request(rqtype, path, params, headers)
      query = params_to_query(params)
      rq = rqtype.new(query.empty? ? path : "#{path}?#{query}", build_request_headers(headers))
      yield rq if block_given?
      http_request(rq)
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
      logger.info "#{rq.method.to_s.upcase} #{site.merge(rq.path)}" if logger
      result = nil
      ms = 1000 * Benchmark.realtime { result = http.request(rq) }
      result = http.request(rq)
      logger.info "--> %d %s (%d %.0fms)" % [result.code, result.message, result.body ? result.body.length : 0, ms] if logger
      handle_response(result)
    rescue Timeout::Error => e
      raise TimeoutError.new(e.message)
    rescue OpenSSL::SSL::SSLError => e
      raise SSLError.new(e.message)
    end

    # Handles response and error codes from remote service.
    def handle_response(response)
      case response.code.to_i
      when 301,302
        raise(Redirection.new(response))
      when 200...400
        response
      when 400
        raise(BadRequest.new(response))
      when 401
        raise(UnauthorizedAccess.new(response))
      when 403
        raise(ForbiddenAccess.new(response))
      when 404
        raise(ResourceNotFound.new(response))
      when 405
        raise(MethodNotAllowed.new(response))
      when 409
        raise(ResourceConflict.new(response))
      when 410
        raise(ResourceGone.new(response))
      when 422
        raise(ResourceInvalid.new(response))
      when 401...500
        raise(ClientError.new(response))
      when 500...600
        raise(ServerError.new(response))
      else
        raise(ConnectionError.new(response, "Unknown response code: #{response.code}"))
      end
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

    # Builds headers for request to remote service.
    def build_request_headers(headers)
      authorization_header.update(headers)
    end

    # Sets authorization header
    def authorization_header
      (@user || @password ? { 'Authorization' => 'Basic ' + ["#{@user}:#{ @password}"].pack('m').delete("\r\n") } : {})
    end

    def logger #:nodoc:
      UnREST.logger
    end
  end
end
