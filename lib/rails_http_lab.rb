require "rails_http_lab/version"
require "rails_http_lab/configuration"

module RailsHttpLab
  class Error < StandardError; end
  class ParseError < Error; end
  class NotFoundError < Error; end
  class OutsideStorageError < Error; end
end

require "rails_http_lab/bruno"
require "rails_http_lab/storage"
require "rails_http_lab/execution"
require "rails_http_lab/engine" if defined?(Rails)
