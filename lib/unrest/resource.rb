require 'forwardable'
require 'stringio'
require 'unrest/connection'
require 'unrest/formats'

module UnREST
  class Resource
    extend Forwardable

    def self.new!(*args, &block)
      r = allocate
      r.send(:initialize!, *args, &block)
      r
    end

    attr_accessor :connection, :format, :path, :params, :headers

    def initialize(site, format = Formats.json, params = {}, headers = {})
      site = site.is_a?(URI) ? site : URI.parse(site)
      initialize!(Connection.new(site), format, site.path, params, headers)
    end

    def initialize!(connection, format, path = nil, params = {}, headers = {})
      @connection, @format, @path, @params, @headers = connection, format, path, params, headers
    end
    private :initialize!

    def_delegators :connection, :site, :user, :password, :timeout, :proxy, :ssl_options,
      :site, :user, :password, :timeout, :proxy, :ssl_options

    def [](path, params = {}, headers = {})
      self.class.new!(connection, format, *merge(path.to_s, params, headers))
    end

    def get(params = {}, headers = {})
      request(params, headers) do |path, params, headers, body|
        connection.get(path, params, headers)
      end
    end

    def post(params = {}, data = nil, headers = {})
      request(params, headers, data) do |path, params, headers, body|
        connection.post(path, params, body, headers)
      end
    end

    def put(params = {}, data = nil, headers = {})
      request(params, headers, data) do |path, params, headers, body|
        connection.put(path, params, body, headers)
      end
    end

    def delete(params = {}, headers = {})
      request(params, headers) do |path, params, headers, body|
        connection.delete(path, params, headers)
      end
    end

    private
    def request(params, headers, data = nil)
      merge('', params, headers) do |path, params, headers|
        format.prepare_request(path, params, headers, data) do |path, params, headers, data|
          handle_response(yield path, params, headers, data)
        end
      end
    end

    def merge(path, params, headers)
      path, params, headers = site.merge(self.path).merge(path).path, self.params.merge(params), self.headers.merge(headers)
      return block_given? ? yield(path, params, headers) : path, params, headers
    end

    def handle_response(response)
      format.interpret_response(response.to_hash, StringIO.new(response.body))
    end
  end
end
