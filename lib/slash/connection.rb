require 'forwardable'
require 'addressable/uri'
require 'slash/exceptions'


module Slash
  class Queue
  end

  class Connection
    extend Forwardable

    attr_accessor :timeout, :proxy

    # Execute a GET request.
    # Used to get (find) resources.
    def get(uri, options = {}, &block)
      request(:get, uri, options, &block)
    end

    # Execute a DELETE request (see HTTP protocol documentation if unfamiliar).
    # Used to delete resources.
    def delete(uri, options = {}, &block)
      request(:delete, uri, options, &block)
    end

    # Execute a PUT request.
    # Used to update resources.
    def put(uri, options = {}, &block)
      request(:put, uri, options, &block)
    end

    # Execute a POST request.
    # Used to create new resources.
    def post(uri, options = {}, &block)
      request(:post, uri, options, &block)
    end

    # Execute a HEAD request.
    # Used to obtain meta-information about resources, such as whether they exist and their size (via response headers).
    def head(uri, options = {}, &block)
      request(:head, uri, options, &block)
    end

    private
    def prepare_request(uri, options)
      case options[:auth]
      when nil, :basic
        user, password = uri.normalized_user, uri.normalized_password
        options.headers['Authorization'] = 'Basic ' + ["#{user}:#{ password}"].pack('m').delete("\r\n") if user || password
      else
        raise ArgumentError, 'unsupported auth'
      end
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
      Slash.logger
    end

    class << self
      attr_writer :default

      def default(&block)
        @default = block if block_given?
        @default
      end

      def create_default
        if @default.respond_to?(:new)
          return @default.new
        else
          return @default.call
        end
      end
    end

    self.default { NetHttpConnection.new }
  end

  autoload :NetHttpConnection, 'slash/nethttp'

  autoload :TyphoeusConnection, 'slash/typhoeus'
  autoload :TyphoeusQueue, 'slash/typhoeus'
end
