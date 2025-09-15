# frozen_string_literal: true

require_relative "actionwebpush/version"

module ActionWebPush
  class Error < StandardError; end

  autoload :Configuration, "actionwebpush/configuration"
  autoload :Notification, "actionwebpush/notification"
  autoload :Pool, "actionwebpush/pool"
  autoload :Base, "actionwebpush/base"

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def config
      self.configuration ||= Configuration.new
    end
  end
end

if defined?(Rails)
  require "actionwebpush/railtie"
  require "actionwebpush/engine"
end
