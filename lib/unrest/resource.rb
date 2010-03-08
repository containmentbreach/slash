require 'forwardable'
require 'addressable/uri'
require 'unrest/connection'
require 'unrest/formats'


module UnREST
  class Resource
    class Response
      extend Forwardable

      def initialize(result, response, exception)
        @result, @response, @exception = result, response, exception
      end

      attr_reader :response, :exception

      def_delegators :response, :code, :headers

      def result
        raise exception if exception
        @result
      end

      def error?
        !exception.nil?
      end
    end

    extend Forwardable

    attr_accessor :connection, :path, :params, :headers

    def_delegators :connection, :run, :site, :user, :password, :timeout, :proxy,
      :site=, :user=, :password=, :timeout=, :proxy=

    def self.new!(*args, &block)
      r = allocate
      r.send(:initialize!, *args, &block)
      r
    end

    def initialize(connection, path, params, headers)
      @connection, @path, @params, @headers = connection, path, params, headers
    end

    def initialize!(from, path, params, headers)
      @connection, @path, @params, @headers = from.connection, *_merge(from, path.to_s, params, headers)
    end
    private :initialize!

    def [](path, params = {}, headers = {})
      self.class.new!(self, path, params, headers)
    end

    def get(params = {}, headers = {}, &block)
      _request(block, params, headers) do |path, params, headers, body, handler|
        connection.get(path, params, headers, &handler)
      end
    end

    def post(params = {}, data = nil, headers = {}, &block)
      _request(block, params, headers, data) do |path, params, headers, body, handler|
        connection.post(path, params, body, headers, &handler)
      end
    end

    def put(params = {}, data = nil, headers = {}, &block)
      _request(block, params, headers, data) do |path, params, headers, body, handler|
        connection.put(path, params, body, headers, &handler)
      end
    end

    def delete(params = {}, headers = {}, &block)
      _request(block, params, headers) do |path, params, headers, body, handler|
        connection.delete(path, params, headers, &handler)
      end
    end

    private
    def prepare_request(path, params, headers, data)
      yield path, params, headers, data
    end

    def handle_response(response)
      begin
        exception = response.exception
      rescue => e
        exception = e
      end
      Response.new(prepare_result(response), response, exception)
    end

    def prepare_result(response)
      response.body
    end

    def request(handler, params, headers, data = nil)
      merge(nil, params, headers) do |path, params, headers|
        prepare_request(path, params, headers, data) do |path, params, headers, data|
          h = handler && proc do |response|
            begin
              handler.call(handle_response(response))
            rescue => e
              logger.error "error in callback: #{e}"
            end
          end
          resp = yield(path, params, headers, data, h)
          handler ? nil : handle_response(resp)
        end
      end
    end

    def merge(path, params, headers, &block)
      _merge(self, path, params, headers, &block)
    end

    def _merge(from, path, params, headers)
      path = if path && !path.empty?
        Addressable::URI.join(from.site, from.path =~ /\/\z/ ? from.path : from.path + '/', path).path
      else
        from.path
      end
      params, headers = from.params.merge(params), from.headers.merge(headers)
      if block_given?
        return yield(path, params, headers)
      else
        return path, params, headers
      end
    end
  end

  class SimpleResource < Resource
    attr_accessor :format

    def initialize(uri, options = {})
      uri = Addressable::URI.parse(uri)
      super(create_connection(uri), uri.path, options[:params] || {}, options[:headers] || {})
      self.format = options[:format]
    end

    def initialize!(from, path, params, headers)
      super
      self.format = from.format
    end

    private
    def create_connection(site)
      UnREST.create_connection(site)
    end

    def prepare_request(path, params, headers, data, &block)
      format ? format.prepare_request(path, params, headers, data, &block) : super
    end

    def prepare_result(response)
      format ? format.interpret_response(response) : super
    end
  end
end
