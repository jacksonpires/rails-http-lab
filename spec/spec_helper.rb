$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Standalone module load (no Rails). Rails-dependent specs use rails_helper.rb.
require "rails_http_lab/version"
require "rails_http_lab/configuration"

# Define top-level error classes that the modules below reference.
module RailsHttpLab
  class Error < StandardError; end
  class ParseError < Error; end
  class NotFoundError < Error; end
  class OutsideStorageError < Error; end
end

require "rails_http_lab/bruno"
require "rails_http_lab/storage"
require "rails_http_lab/execution"

RSpec.configure do |c|
  c.expect_with :rspec do |e|
    e.syntax = :expect
  end
end

FIXTURES_ROOT = File.expand_path("fixtures", __dir__)
BRUNO_CORPUS  = File.join(FIXTURES_ROOT, "bruno_corpus")
