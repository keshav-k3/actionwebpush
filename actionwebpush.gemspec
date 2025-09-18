# frozen_string_literal: true

require_relative "lib/actionwebpush/version"

Gem::Specification.new do |spec|
  spec.name = "actionwebpush"
  spec.version = ActionWebPush::VERSION
  spec.authors = ["Keshav Kk"]
  spec.email = ["keshavkk.musafir@gmail.com"]

  spec.summary = "Rails integration for Web Push notifications"
  spec.description = "ActionWebPush provides Rails integration for Web Push notifications with ActionMailer-like interface, thread pool management, and subscription handling."
  spec.homepage = "https://github.com/keshav-k3/actionwebpush"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/keshav-k3/actionwebpush"
  spec.metadata["changelog_uri"] = "https://github.com/keshav-k3/actionwebpush/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile]) ||
        f.end_with?('.gem')
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "rails", "~> 6.0", ">= 6.0.0"
  spec.add_dependency "web-push", "~> 3.0"
  spec.add_dependency "concurrent-ruby", "~> 1.1"
  spec.add_dependency "net-http-persistent", "~> 4.0"

  # Development dependencies
  spec.add_development_dependency "sqlite3", "~> 1.4"
  spec.add_development_dependency "resque", "~> 2.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
