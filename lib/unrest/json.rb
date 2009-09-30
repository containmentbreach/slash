require 'json'
require 'unrest/formats'

module UnREST
  module Formats
    class JSON < GenericFormat
      def initialize(suffix = '.json', mime = 'application/json')
        super
      end

      def encode(data)
        data.to_hash.to_json
      end

      def decode(data)
        ::JSON.parse(data.read)
      end
    end
  end
end
