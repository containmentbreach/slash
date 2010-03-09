require 'forwardable'
require 'addressable/uri'
require 'slash/connection'
require 'slash/formats'


module Slash
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

    attr_accessor :connection, :uri, :params, :headers, :user, :password, :timeout, :proxy

    def_delegator :uri, :path
    def_delegator :uri, :query_values, :query

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

    def initialize(connection, uri, options = {})
      @connection = connection
      @uri = Addressable::URI.parse(uri)
      query = options[:query]
      if query && !query.empty?
        @uri = @uri.dup
        uq = @uri.query_values
        @uri.query_values = uq ? uq.merge(query) : query
      end
      @params, @headers = (options[:params] || {}).to_mash, options[:headers] || {}
      self.user_agent ||= options[:user_agent] || Slash::USER_AGENT
    end

    def initialize!(from, options)
      @connection = from.connection
      options = _merge(from, options)
      @uri, @params, @headers = options[:uri], options[:params], options[:headers]
    end
    private :initialize!

    def slash(options = {})
      self.class.new!(self, options)
    end

    def [](path)
      slash(:path => path)
    end

    # Execute a GET request.
    # Used to get (find) resources.
    def get(options = {}, &block)
      request(options.merge(:method => :get), &block)
    end

    # Execute a DELETE request (see HTTP protocol documentation if unfamiliar).
    # Used to delete resources.
    def delete(options = {}, &block)
      request(options.merge(:method => :delete), &block)
    end

    # Execute a PUT request.
    # Used to update resources.
    def put(options = {}, &block)
      request(options.merge(:method => :put), &block)
    end

    # Execute a POST request.
    # Used to create new resources.
    def post(options = {}, &block)
      request(options.merge(:method => :post), &block)
    end

    # Execute a HEAD request.
    # Used to obtain meta-information about resources, such as whether they exist and their size (via response headers).
    def head(options = {}, &block)
      request(options.merge(:method => :head), &block)
    end

    def request(options)
      rq = prepare_request(merge(options))
      connection.request(rq.delete(:method), rq.delete(:uri), rq) do |response|
        resp = handle_response(response)
        block_given? ? yield(resp) : resp
      end
    end

    private
    def prepare_request(options)
      options[:body] = options.delete(:data).to_s
      options
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

    def merge(options, &block)
      _merge(self, options, &block)
    end

    def _merge(from, options)
      options = options.dup
      path, query, params, headers = options[:path], options[:query], options[:params], options[:headers]

      u = options[:uri] = from.uri.dup

      uq = u.query_values(:notation => :flat)
      uq = uq ? (query ? uq.to_mash.merge(query) : uq) : query
      if path
        upath = u.path
        u.path = upath + '/' unless upath =~ /\/\z/
        u.join!(path)
      end
      u.query_values = uq

      p = options[:params] = from.params.dup
      p.merge!(params) if params && !params.empty?

      h = options[:headers] = from.headers.dup
      h.merge!(headers) if headers && !headers.empty?

      options
    end
  end

  class SimpleResource < Resource
    attr_accessor :format

    def initialize(uri, options = {})
      super(options[:connection] || create_connection, uri, options)
      self.format = options[:format]
    end

    private
    def initialize!(from, options)
      super
      self.format = from.format
    end

    def create_connection
      Connection.create_default
    end

    def prepare_request(options)
      format ? format.prepare_request(options) : super
    end

    def prepare_result(response)
      response.success? && format ? format.interpret_response(response) : super
    end
  end
end
