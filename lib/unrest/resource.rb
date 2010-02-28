require 'forwardable'
require 'unrest/base'
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

    def self.new!(*args, &block)
      r = allocate
      r.send(:initialize!, *args, &block)
      r
    end

    attr_accessor :connection, :format, :path, :params, :headers

    def initialize(site, format = Formats.json, params = {}, headers = {})
      initialize!(UnREST.default_connection.new(site), format, site.path, params, headers)
    end

    def initialize!(connection, format = Formats.json, path = nil, params = {}, headers = {})
      @connection, @format, @path, @params, @headers = connection, format, path || '', params, headers
    end

    def_delegators :connection, :run, :site, :user, :password, :timeout, :proxy,
      :site=, :user=, :password=, :timeout=, :proxy=

    def [](path, params = {}, headers = {})
      self.class.new!(connection, format, *merge(path.to_s, params, headers))
    end

    def get(params = {}, headers = {}, &block)
      request(block, params, headers) do |path, params, headers, body, handler|
        connection.get(path, params, headers, &handler)
      end
    end

    def post(params = {}, data = nil, headers = {}, &block)
      request(block, params, headers, data) do |path, params, headers, body, handler|
        connection.post(path, params, body, headers, &handler)
      end
    end

    def put(params = {}, data = nil, headers = {}, &block)
      request(block, params, headers, data) do |path, params, headers, body, handler|
        connection.put(path, params, body, headers, &handler)
      end
    end

    def delete(params = {}, headers = {}, &block)
      request(block, params, headers) do |path, params, headers, body, handler|
        connection.delete(path, params, headers, &handler)
      end
    end

    private
    def request(handler, params, headers, data = nil)
      merge(nil, params, headers) do |path, params, headers|
        format.prepare_request(path, params, headers, data) do |path, params, headers, data|
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

    def merge(path, params, headers)
      path = if path && !path.empty?
        site.merge(self.path =~ /\/\z/ ? self.path : self.path + '/').merge(path).path
      else
        self.path
      end
      params, headers = self.params.merge(params), self.headers.merge(headers)
      if block_given?
        return yield(path, params, headers)
      else
        return path, params, headers
      end
    end

    def handle_response(response)
      begin
        exception = response.exception
        result = format.interpret_response(response)
      rescue => exception
      end
      Response.new(result, response, exception)
    end
  end
end
