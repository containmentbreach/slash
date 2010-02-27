require 'typhoeus'
require 'stringio'
require 'unrest/base'


module UnREST
  class TyphoeusConnection < BaseConnection
    def initialize(site, hydra = nil)
      super(site)
      @hydra = case hydra
      when nil
        Typhoeus::Hydra.new
      when Hash
        Typhoeus::Hydra.new(hydra)
      else
        hydra
      end
    end

    attr_accessor :hydra

    # Execute a GET request.
    # Used to get (find) resources.
    def get(path = nil, params = {}, headers = {}, &block)
      request(:get, path, params, headers, &block)
    end

    # Execute a DELETE request (see HTTP protocol documentation if unfamiliar).
    # Used to delete resources.
    def delete(path, params = {}, headers = {}, &block)
      request(:delete, path, params, headers, &block)
    end

    # Execute a PUT request (see HTTP protocol documentation if unfamiliar).
    # Used to update resources.
    def put(path, params = {}, body = nil, headers = {}, &block)
      request(:put, path, params, headers, body, &block)
    end

    # Execute a POST request.
    # Used to create new resources.
    def post(path, params = {}, body = nil, headers = {}, &block)
      request(:post, path, params, headers, body, &block)
    end

    # Execute a HEAD request.
    # Used to obtain meta-information about resources, such as whether they exist and their size (via response headers).
    def head(path, params = {}, headers = {}, &block)
      request(:head, path, params, headers, &block)
    end

    def run
      hydra.run
    end

    private
    def request(method, path, params, headers, body = nil)
      uri = site
      uri = uri.merge(path) if path

      logger.info "#{method.to_s.upcase} #{uri}" if logger

      rq = Typhoeus::Request.new(uri.to_s,
        :method => method,
        :headers => build_request_headers(headers),
        :params => params && params.inject({}) {|h, x| h[x[0].to_s] = x[1] || ''; h },
        :body => body,
        :timeout => timeout
      )
      rq.on_complete do |response|
        response = augment_response(response)
        yield response if block_given?
        response
      end
      hydra.queue(rq)
      if block_given?
        nil
      else
        run
        check_and_raise(rq.handled_response)
      end
    end

    private
    def augment_response(response)
      class << response
        attr_accessor :exception

        def body_stream
          body && StringIO.new(body)
        end
      end

      handle_response(response)
    end
  end
end
