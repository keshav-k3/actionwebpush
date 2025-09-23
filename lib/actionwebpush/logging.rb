# frozen_string_literal: true

require "logger"

module ActionWebPush
  module Logging
    def logger
      ActionWebPush.logger
    end

    module_function :logger
  end

  class << self
    def logger
      @logger ||= config.logger || default_logger
    end

    def logger=(logger)
      @logger = logger
    end

    private

    def default_logger
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger
      else
        Logger.new(STDOUT).tap do |log|
          log.level = Logger::INFO
          log.formatter = proc do |severity, datetime, progname, msg|
            "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity} -- ActionWebPush: #{msg}\n"
          end
        end
      end
    end
  end
end