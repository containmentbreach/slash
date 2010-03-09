module Slash
  module Formats
    autoload :JSON, 'slash/json'
    autoload :PeanutsXML, 'slash/peanuts'

    def self.xml(options = {})
      Format.new({:mime => 'application/xml'}.update(options))
    end

    def self.json(options = {})
      options = {:mime => 'application/json'}.update(options)
      options[:codec] ||= JSON
      Format.new(options)
    end

    class Format
      attr_reader :mime, :codec

      def initialize(options)
        @codec = options[:codec]
        @mime = options[:mime] || (@codec.respond_to?(:mime) ? @codec.mime : nil)
      end

      def prepare_request(options)
        headers = options[:headers]
        headers['Accept'] = mime if mime
        data = options.delete(:data)
        if data
          options[:body] = codec.encode(data)
          headers['Content-Type'] = mime if mime
        end
        options
      end

      def interpret_response(response)
        bs = response.body_stream
        bs && codec.decode(bs)
      end
    end

    class WithSuffix < Format
      attr_reader :suffix

      def initialize(mime, suffix, codec)
        super(mime, codec)
        @suffix = suffix
      end

      def prepare_request(options, &block)
        options[:path] += suffix if suffix
        super
      end

      def self.xml(options = {})
        WithSuffix.new(options.fetch(:mime, 'application/xml'),
          options.fetch(:suffix, '.xml'),
          options.fetch(:codec))
      end

      def self.json(options = {})
        WithSuffix.new(options.fetch(:mime, 'application/json'),
          options.fetch(:suffix, '.json'),
          options.fetch(:codec) { JSON })
      end
    end
  end
end
