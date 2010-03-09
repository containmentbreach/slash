require 'peanuts'
require 'slash/formats'

module Slash
  module Formats
    class PeanutsXML
      attr_reader :response_type
      attr_accessor :to_xml_options, :from_xml_options

      def initialize(response_type, from_xml_options = {}, to_xml_options = {})
        @response_type = response_type
        @to_xml_options, @from_xml_options = to_xml_options, from_xml_options
      end

      def encode(data)
        data.to_xml(:string, to_xml_options)
      end

      def decode(data)
        response_type.from_xml(data, from_xml_options)
      end
    end
  end
end
