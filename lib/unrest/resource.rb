require 'forwardable'
require 'unrest/base'
require 'unrest/formats'


module UnREST
  class Resource
    class Result
      def initialize(r)
        @r = r
      end

      def get
        raise @r if @r.is_a?(Exception)
        @r
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

    def_delegators :connection, :site, :user, :password, :timeout, :proxy,
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
          h = proc do |response|
            result = begin
              handle_response(response)
            rescue Exception => e
              e
            end
            begin
              handler.call(Result.new(result))
            rescue
              # swallow
            end
          end
          resp = yield(path, params, headers, data, handler && h)
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
      raise response.exception if response.exception
      format.interpret_response(response)
    end
  end
end
