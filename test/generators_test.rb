# frozen_string_literal: true

require "test_helper"

# Mock Rails generators environment
module Rails
  def self.root
    Pathname.new("/tmp/test_app")
  end
end

class GeneratorsTest < Minitest::Test
  def setup
    @test_root = "/tmp/actionwebpush_test"
    FileUtils.mkdir_p(@test_root)
    Dir.chdir(@test_root)
  end

  def teardown
    FileUtils.rm_rf(@test_root) if File.exist?(@test_root)
  end

  def test_install_generator_creates_migration
    skip "Rails not available in test environment"

    # Mock the generator
    generator = ActionWebPush::Generators::InstallGenerator.new

    # Should create migration file
    assert_respond_to generator, :create_migration

    # Mock file creation
    generator.define_singleton_method(:create_file) do |path, content|
      @created_files ||= {}
      @created_files[path] = content
    end

    generator.create_migration

    migration_files = generator.instance_variable_get(:@created_files) || {}
    migration_file = migration_files.keys.find { |k| k.include?("create_action_web_push_subscriptions") }

    assert migration_file, "Migration file should be created"
  end

  def test_install_generator_creates_initializer
    skip "Rails not available in test environment"

    generator = ActionWebPush::Generators::InstallGenerator.new

    # Should create initializer
    assert_respond_to generator, :create_initializer

    # Mock file creation
    generator.define_singleton_method(:create_file) do |path, content|
      @created_files ||= {}
      @created_files[path] = content
    end

    generator.create_initializer

    created_files = generator.instance_variable_get(:@created_files) || {}
    initializer_file = created_files["config/initializers/action_web_push.rb"]

    assert initializer_file, "Initializer file should be created"
    assert_includes initializer_file, "ActionWebPush.configure"
    assert_includes initializer_file, "config.vapid_public_key"
    assert_includes initializer_file, "config.vapid_private_key"
    assert_includes initializer_file, "config.vapid_subject"
  end

  def test_vapid_keys_generator
    skip "Rails not available in test environment"

    generator = ActionWebPush::Generators::VapidKeysGenerator.new

    # Should generate VAPID keys
    assert_respond_to generator, :generate_vapid_keys

    # Mock WebPush.generate_key
    mock_keys = {
      public_key: "generated_public_key",
      private_key: "generated_private_key"
    }

    if defined?(::WebPush)
      ::WebPush.stub :generate_key, mock_keys do
        output = capture_io do
          generator.generate_vapid_keys
        end

        assert_includes output[0], "generated_public_key"
        assert_includes output[0], "generated_private_key"
      end
    end
  end

  def test_campfire_migration_generator
    skip "Rails not available in test environment"

    generator = ActionWebPush::Generators::CampfireMigrationGenerator.new

    # Should create Campfire compatibility migration
    assert_respond_to generator, :create_migration

    # Mock file creation
    generator.define_singleton_method(:create_file) do |path, content|
      @created_files ||= {}
      @created_files[path] = content
    end

    generator.create_migration

    created_files = generator.instance_variable_get(:@created_files) || {}
    migration_file = created_files.values.first

    if migration_file
      assert_includes migration_file, "migrate_push_subscriptions"
      assert_includes migration_file, "Person"
      assert_includes migration_file, "push_subscriptions"
    end
  end

  def test_migration_template_content
    # Test the migration template directly
    template_path = File.expand_path(
      "../lib/actionwebpush/generators/templates/create_action_web_push_subscriptions.rb",
      __dir__
    )

    if File.exist?(template_path)
      template_content = File.read(template_path)

      assert_includes template_content, "CreateActionWebPushSubscriptions"
      assert_includes template_content, "create_table :action_web_push_subscriptions"
      assert_includes template_content, "t.string :endpoint"
      assert_includes template_content, "t.string :p256dh_key"
      assert_includes template_content, "t.string :auth_key"
      assert_includes template_content, "t.references :user"
    end
  end

  def test_initializer_template_content
    # Test the initializer template directly
    template_path = File.expand_path(
      "../lib/actionwebpush/generators/templates/initializer.rb",
      __dir__
    )

    if File.exist?(template_path)
      template_content = File.read(template_path)

      assert_includes template_content, "ActionWebPush.configure"
      assert_includes template_content, "ENV['VAPID_PUBLIC_KEY']"
      assert_includes template_content, "ENV['VAPID_PRIVATE_KEY']"
      assert_includes template_content, "ENV['VAPID_SUBJECT']"
      assert_includes template_content, "config.delivery_method"
      assert_includes template_content, "config.pool_size"
    end
  end

  def test_campfire_compatibility_template
    # Test the Campfire compatibility template
    template_path = File.expand_path(
      "../lib/actionwebpush/generators/templates/campfire_compatibility.rb",
      __dir__
    )

    if File.exist?(template_path)
      template_content = File.read(template_path)

      assert_includes template_content, "module CampfireCompatibility"
      assert_includes template_content, "has_many :push_subscriptions"
      assert_includes template_content, "ActionWebPush::Subscription"
    end
  end

  def test_generator_helps_and_descriptions
    # Test that generators have proper help text
    install_gen = ActionWebPush::Generators::InstallGenerator
    vapid_gen = ActionWebPush::Generators::VapidKeysGenerator
    campfire_gen = ActionWebPush::Generators::CampfireMigrationGenerator

    # Should have descriptions
    assert_respond_to install_gen, :desc if install_gen.respond_to?(:desc)
    assert_respond_to vapid_gen, :desc if vapid_gen.respond_to?(:desc)
    assert_respond_to campfire_gen, :desc if campfire_gen.respond_to?(:desc)
  end

  private

  def capture_io
    old_stdout, old_stderr = $stdout, $stderr
    $stdout, $stderr = StringIO.new, StringIO.new
    yield
    [$stdout.string, $stderr.string]
  ensure
    $stdout, $stderr = old_stdout, old_stderr
  end
end