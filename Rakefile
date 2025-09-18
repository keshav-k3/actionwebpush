# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList[
    "test/basic_test.rb",
    "test/comprehensive_test.rb",
    "test/delivery_methods_test.rb"
  ]
  t.verbose = true
end

task default: :test
