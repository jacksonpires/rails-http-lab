require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "sprockets/railtie"

Bundler.require(*Rails.groups)
require "rails_http_lab"
require "rails_http_lab/engine"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.api_only = false
    config.consider_all_requests_local = true
    config.hosts.clear
    config.secret_key_base = "rails-http-lab-test-secret"
    config.cache_classes = false
    config.active_support.to_time_preserves_timezone = :zone if config.active_support.respond_to?(:to_time_preserves_timezone)
  end
end
