require 'json'
require 'unrest/formats'

module UnREST
  module Formats
    class JSON < GenericFormat
      def initialize(suffix = '.json', mime = 'application/json')
        super
      end

      def encode(data)
        ::JSON.generate(data)
      end

      def decode(data)
        ::JSON.parse(data.read)
      end
    end
  end
end
