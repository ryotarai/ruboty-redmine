require "active_support/core_ext/hash/keys"

require "ruboty/redmine/version"
require "ruboty/redmine/client"
require "ruboty/handlers/redmine"

module Ruboty
  module Redmine
    def self.log(msg)
      Ruboty.logger.info "[redmine] #{msg}"

      # FIX: thix dirty hack.
      Ruboty.logger.instance_variable_get(:@logdev).dev.flush
    end
  end
end
