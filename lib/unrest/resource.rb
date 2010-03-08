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

      def success?
        exception.nil?
      end
    end

    extend Forwardable

    attr_accessor :connection, :path, :params, :headers

    def_delegators :connection, :run, :site, :user, :password, :timeout, :proxy,
      :site=, :user=, :password=, :timeout=, :proxy=

    def user_agent
      headers['User-Agent']
    end

    def user_agent=(value)
      headers['User-Agent'] = value
    end

    def self.new!(*args, &block)
      r = allocate
      r.send(:initialize!, *args, &block)
      r
    end

    def initialize(connection, options = {})
      @connection = connection
      @path, @params, @headers = options[:path] || '', options[:params] || {}, options[:headers] || {}
      self.user_agent ||= UnREST::USER_AGENT
    end

    def initialize!(from, path, params, headers)
      @connection, @path, @params, @headers = from.connection, *_merge(from, path.to_s, params, headers)
    end
    private :initialize!

    def slash(options)
      self.class.new!(self, options[:path], options[:params] || {}, options[:headers] || {})
    end

    def [](path)
      slash(:path => path)
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

    def request(method, options)
      merge(options[:params] || {}, options[:headers] || {}) do |path, params, headers|
        prepare_request(method,
          :path => path,
          :params => params,
          :headers => headers,
          :data => options[:data],
          :async => options[:async]
        ) do |request|
          connection.request(method, request) do |response|
            resp = handle_response(response)
            block_given? ? yield(resp) : resp
          end
        end
      end
    end

    private
    def prepare_request(method, options)
      options[:body] = options.delete(:data).to_s
      yield options
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

    def merge(params, headers, &block)
      _merge(self, nil, params, headers, &block)
    end

    def _merge(from, path, params, headers)
      path = if path && !path.empty?
        Addressable::URI.join(from.site, from.path =~ /\/\z/ ? from.path : from.path + '/', path).path
      else
        from.path
      end
      params, headers = from.params.merge(params), from.headers.merge(headers)
      if block_given?
        yield(path, params, headers)
      else
        return path, params, headers
      end
    end
  end

  class SimpleResource < Resource
    attr_accessor :format

    def initialize(uri, options = {})
      conn = if uri.is_a?(Connection)
        uri
      else
        uri = Addressable::URI.parse(uri)
        options = {:path => uri.path}.update(options)
        create_connection(uri)
      end
      super(conn, options)
      self.format = options[:format]
    end

    private
    def initialize!(from, path, params, headers)
      super
      self.format = from.format
    end

    def create_connection(site)
      UnREST.create_connection(site)
    end

    def prepare_request(method, options, &block)
      format ? format.prepare_request(method, options, &block) : super
    end

    def prepare_result(response)
      response.success? && format ? format.interpret_response(response) : super
    end
  end
end
