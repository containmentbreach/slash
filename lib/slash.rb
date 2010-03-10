require 'extlib'
require 'slash/formats'
require 'slash/resource'

module Slash
  USER_AGENT = 'Slash 0.4.2 (http://github.com/omg/slash)'

  class << self
    attr_accessor :logger
  end
end
