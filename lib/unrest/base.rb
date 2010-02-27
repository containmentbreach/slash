require 'uri'
require 'unrest/exceptions'


module UnREST
  class BaseConnection
    attr_accessor :site, :user, :password, :timeout, :proxy

    # The +site+ parameter is required and will set the +site+
    # attribute to the URI for the remote resource service.
    def initialize(site)
      raise ArgumentError, 'Missing site URI' unless site
      self.site = site
    end

    # Set URI for remote service.
    def site=(site)
      @site = site.is_a?(URI) ? site : URI.parse(site)
      (@site = @site.dup).path = '' unless @site.path.empty?

      @user = URI.decode(@site.user) if @site.user
      @password = URI.decode(@site.password) if @site.password
    end

    def run
      # no op
    end

    private
    # Builds headers for request to remote service.
    def build_request_headers(headers)
      h = authorization_header
      h.update(headers) if headers
    end

    # Sets authorization header
    def authorization_header
      (@user || @password ? { 'Authorization' => 'Basic ' + ["#{@user}:#{ @password}"].pack('m').delete("\r\n") } : {})
    end

    # Handles response and error codes from remote service.
    def handle_response(response)
      response.exception = case response.code.to_i
      when 301,302
        Redirection.new(response)
      when 200...400
        nil
      when 400
        BadRequest.new(response)
      when 401
        UnauthorizedAccess.new(response)
      when 403
        ForbiddenAccess.new(response)
      when 404
        ResourceNotFound.new(response)
      when 405
        MethodNotAllowed.new(response)
      when 409
        ResourceConflict.new(response)
      when 410
        ResourceGone.new(response)
      when 422
        ResourceInvalid.new(response)
      when 401...500
        ClientError.new(response)
      when 500...600
        ServerError.new(response)
      else
        ConnectionError.new(response, "Unknown response code: #{response.code}")
      end
      response
    end

    def check_and_raise(response)
      raise response.exception if response.exception
      response
    end

    def logger #:nodoc:
      UnREST.logger
    end
  end

  def self.default_connection
    @@default_connection ||= NetHttpConnection
  end

  def self.default_connection=(cls)
    @@default_connection = cls
  end

  autoload :NetHttpConnection, 'unrest/nethttp'
  autoload :TyphoeusConnection, 'unrest/typhoeus'
end
