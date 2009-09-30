module UnREST
  module Formats
    autoload :JSON, 'unrest/json'
    autoload :PeanutsXML, 'unrest/peanuts'

    def self.xml(options = {})
      Format.new(options.fetch(:mime, 'application/xml'), options.fetch(:codec))
    end

    def self.json(options = {})
      Format.new(options.fetch(:mime, 'application/json'), options.fetch(:codec) { JSON })
    end

    class Format
      attr_reader :mime, :codec

      def initialize(mime, codec)
        @mime, @codec = mime, codec
      end

      def prepare_request(path, params, headers, data)
        headers['Accept'] = mime
        if data
          data = codec.encode(data)
          headers['Content-Type'] = mime
        end
        yield path, params, headers, data
      end

      def interpret_response(headers, body)
        codec.decode(body)
      end
    end

    class WithSuffix < Format
      attr_reader :suffix

      def initialize(mime, suffix, codec)
        super(mime, codec)
        @suffix = suffix
      end

      def prepare_request(path, params, headers, data, &block)
        path += suffix if suffix
        super(path, params, headers, data)
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
