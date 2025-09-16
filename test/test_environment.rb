# frozen_string_literal: true

# Test environment setup for Ruby 2.6 compatibility

# Mock Rails modules before they're required
$LOAD_PATH.unshift File.expand_path("mocks", __dir__)

# Create fake rails module files in memory
module RailsRailtie
  # Mock railtie
end

# Override require to handle Rails dependencies
original_require = method(:require)

define_method(:require) do |name|
  case name
  when "rails/railtie", "rails/engine", "web-push", "concurrent-ruby"
    # Silently ignore these requires - they're mocked
    true
  else
    original_require.call(name)
  end
end

# Stub WebPush before any requires
module WebPush
  class ResponseError < StandardError
    attr_reader :response, :uri

    def initialize(message, response = nil, uri = nil)
      @response = response
      @uri = uri
      super(message)
    end
  end

  class ExpiredSubscription < ResponseError; end
  class InvalidSubscription < ResponseError; end

  def self.payload_send(message:, endpoint:, p256dh:, auth:, vapid: {}, **options)
    MockResponse.new(200, "OK", {})
  end

  def self.generate_key
    {
      public_key: "mock_public_key_" + SecureRandom.hex(32),
      private_key: "mock_private_key_" + SecureRandom.hex(32)
    }
  end

  class MockResponse
    attr_reader :code, :body, :headers

    def initialize(code, body, headers = {})
      @code = code
      @body = body
      @headers = headers
    end

    def success?
      code.to_i == 200
    end

    def inspect
      "#<MockResponse:#{object_id} @code=#{code} @body=#{body.inspect}>"
    end
  end
end

# Stub Concurrent Ruby
module Concurrent
  class ThreadPoolExecutor
    def initialize(options = {})
      @options = options
      @shutdown = false
    end

    def post(&block)
      Thread.new(&block)
    end

    def shutdown
      @shutdown = true
    end

    def shutdown?
      @shutdown
    end

    def wait_for_termination(timeout = nil)
      true
    end
  end

  class Future
    def initialize(&block)
      @thread = Thread.new(&block)
    end

    def value(timeout = nil)
      @thread.join(timeout)
      @thread.value
    end

    def complete?
      !@thread.alive?
    end
  end

  class AtomicInteger
    def initialize(value = 0)
      @value = value
      @mutex = Mutex.new
    end

    def increment
      @mutex.synchronize { @value += 1 }
    end

    def value
      @mutex.synchronize { @value }
    end
  end
end

# Mock Rails components
module Rails
  def self.root
    Pathname.new("/tmp/test_app")
  end

  def self.logger
    Logger.new(STDOUT)
  end

  def self.env
    "test"
  end

  class Railtie
    def self.inherited(klass)
      # Mock railtie inheritance
    end

    def self.config
      @config ||= RailtieConfig.new
    end

    def self.initializer(name, options = {}, &block)
      # Mock initializer registration
    end
  end

  class RailtieConfig
    def action_web_push=(value)
      @action_web_push = value
    end

    def action_web_push
      @action_web_push ||= ActiveSupport::OrderedOptions.new
    end

    def generators
      @generators ||= OpenStruct.new
    end
  end

  class Engine < Railtie
    def self.inherited(klass)
      # Mock engine inheritance
    end

    def self.isolate_namespace(mod)
      # Mock namespace isolation
    end
  end

  def self.application
    @application ||= Application.new
  end

  class Application
    def config
      @config ||= Config.new
    end
  end

  class Config
    def action_web_push
      @action_web_push ||= OpenStruct.new
    end

    def x
      @x ||= OpenStruct.new
    end

    def autoload_paths
      @autoload_paths ||= []
    end
  end

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.executor
    @executor ||= MockExecutor.new
  end

  class MockExecutor
    def wrap
      yield if block_given?
    end
  end
end

module ActiveSupport
  class OrderedOptions < Hash
    def method_missing(method, *args)
      if method.to_s.end_with?('=')
        self[method.to_s.chomp('=').to_sym] = args.first
      else
        self[method]
      end
    end

    def respond_to_missing?(method, include_private = false)
      true
    end
  end
end

module ActiveJob
  class Base
    def self.perform_later(*args)
      new.perform(*args)
    end

    def perform(*args)
      # Override in subclasses
    end
  end
end

module ActiveRecord
  class Base
    def self.has_many(association, options = {})
      # Mock association
    end

    def self.belongs_to(association, options = {})
      # Mock association
    end

    def self.validates(field, options = {})
      # Mock validation
    end
  end

  class Migration
    def self.[](version)
      self
    end

    def change
      # Override in subclasses
    end

    def create_table(name, options = {})
      yield TableDefinition.new if block_given?
    end

    def add_index(table, columns, options = {})
      # Mock index creation
    end
  end

  class TableDefinition
    def string(name, options = {})
      # Mock column
    end

    def text(name, options = {})
      # Mock column
    end

    def references(name, options = {})
      # Mock reference
    end

    def timestamps(options = {})
      # Mock timestamps
    end
  end
end

# Load required libraries
require "logger"
require "json"
require "pathname"
require "securerandom"
require "ostruct"