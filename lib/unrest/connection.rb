require 'forwardable'
require 'addressable/uri'
require 'unrest/exceptions'


module UnREST
  class Connection
    extend Forwardable

    attr_reader :site
    attr_accessor :timeout, :proxy

    def_delegators :site, :host, :user, :password, :user=, :password=

    # The +site+ parameter is required and will set the +site+
    # attribute to the URI for the remote resource service.
    def initialize(site)
      raise ArgumentError, 'Missing site URI' unless site
      self.site = site
    end

    # Set URI for remote service.
    def site=(site)
      @site = Addressable::URI.parse(site).dup
      @site.path = @site.query = @site.fragment = nil
      @site
    end

    def run
      # no op
    end

    # Execute a GET request.
    # Used to get (find) resources.
    def get(options = {}, &block)
      request(:get, options, &block)
    end

    # Execute a DELETE request (see HTTP protocol documentation if unfamiliar).
    # Used to delete resources.
    def delete(options = {}, &block)
      request(:delete, options, &block)
    end

    # Execute a PUT request.
    # Used to update resources.
    def put(options = {}, &block)
      request(:put, options, &block)
    end

    # Execute a POST request.
    # Used to create new resources.
    def post(options = {}, &block)
      request(:post, options, &block)
    end

    # Execute a HEAD request.
    # Used to obtain meta-information about resources, such as whether they exist and their size (via response headers).
    def head(options = {}, &block)
      request(:head, options, &block)
    end

    private
    # Builds headers for request to remote service.
    def build_request_headers(headers)
      authorization_header.update(headers || {})
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

  def self.create_connection(site = nil, &block)
    if block_given?
      @@create_connection = block
    elsif @@create_connection.respond_to?(:new)
      return @@create_connection.new(site)
    else
      return @@create_connection.call(site)
    end
  end
  
  def self.create_connection=(cls)
    @@create_connection = cls
  end

  create_connection {|site| NetHttpConnection.new(site) }


  autoload :NetHttpConnection, 'unrest/nethttp'
  autoload :TyphoeusConnection, 'unrest/typhoeus'
end
