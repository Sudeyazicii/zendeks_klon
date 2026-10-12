ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # SQLite için tekil işlemci ile deterministik testler
    parallelize(workers: 1)

    include ActiveSupport::Testing::TimeHelpers
  end
end
