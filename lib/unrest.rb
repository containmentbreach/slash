require 'unrest/formats'
require 'unrest/resource'

module UnREST
  USER_AGENT = 'UnREST 0.3.4 (http://github.com/omg/unrest)'

  class << self
    attr_accessor :logger
  end
end
