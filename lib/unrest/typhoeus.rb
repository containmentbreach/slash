require 'typhoeus'
require 'stringio'
require 'unrest/connection'


module UnREST
  class TyphoeusConnection < Connection
    def initialize(site, hydra_or_options = nil)
      super(site)
      case hydra_or_options
      when nil
        @hydra = Typhoeus::Hydra.new
        @hydra.disable_memoization
      when Hash
        @hydra = Typhoeus::Hydra.new(hydra_or_options)
        @hydra.disable_memoization
      else
        @hydra = hydra_or_options
      end
    end

    attr_accessor :hydra

    def run
      hydra.run
    end

    def request(method, options = {})
      path, params, headers, body = options[:path], options[:params], options[:headers], options[:body]

      uri = site
      uri = uri.merge(:path => path) if path
      
      headers = build_request_headers(headers)

      rq = Typhoeus::Request.new(uri.to_s,
        :method => method,
        :headers => headers,
        :params => params && params.inject({}) {|h, x| h[x[0].to_s] = x[1] || ''; h },
        :body => body,
        :timeout => options[:timeout] || timeout,
        :user_agent => headers['User-Agent']
      )
      ret = nil
      rq.on_complete do |response|
        if logger
          logger.debug "%s %s --> %d (%d %.0fs)" % [rq.method.to_s.upcase, rq.url,
            response.code, response.body ? response.body.length : 0, response.time]
        end
        ret = response = augment_response(response)
        ret = yield response if block_given?
        response
      end
      hydra.queue(rq)
      if options[:async]
        nil
      else
        run
        check_and_raise(rq.handled_response)
        ret
      end
    end

    private
    def augment_response(response)
      class << response
        attr_accessor :exception
        def body_stream
          body && StringIO.new(body)
        end
        def success?
          exception.nil?
        end
      end

      handle_response(response)
    end
  end
end
