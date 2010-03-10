require 'typhoeus'
require 'forwardable'
require 'stringio'
require 'slash/connection'


module Slash
  class TyphoeusQueue < Queue
    extend Forwardable

    def initialize(hydra_or_options = nil)
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

    def_delegator :hydra, :queue, :submit
    def_delegator :hydra, :run
  end

  class TyphoeusConnection < Connection
    def initialize(options = {})
      @queue = options[:queue] || TyphoeusQueue.new
    end

    attr_accessor :queue

    def request(method, uri, options = {})
      options = options.dup
      prepare_request(uri, options)

      params, headers = options[:params], options[:headers]
      rq = Typhoeus::Request.new(uri.to_s,
        :method => method,
        :headers => headers,
        :params => !params.blank? ? params.inject({}) {|h, x| h[x[0].to_s] = x[1] || ''; h } : nil,
        :body => options[:body],
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
      async = options[:async]
      queue = [true, false, nil].include?(async) ? self.queue : async
      queue.submit(rq)
      if async
        queue
      else
        queue.run
        block_given? ? ret : check_and_raise(rq.handled_response)
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
