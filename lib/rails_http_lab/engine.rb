require "rails/engine"

module RailsHttpLab
  class Engine < ::Rails::Engine
    isolate_namespace RailsHttpLab

    initializer "rails_http_lab.assets" do |app|
      if app.config.respond_to?(:assets) && app.config.assets.respond_to?(:precompile)
        app.config.assets.precompile += %w[rails_http_lab/application.css rails_http_lab/application.js]
      end
    end

    config.after_initialize do
      cfg = RailsHttpLab.config
      if cfg.enabled_envs.include?(:production) &&
         defined?(Rails) && Rails.env.production? &&
         cfg.authenticator.nil?
        raise <<~MSG
          [rails-http-lab] Refusing to boot: production is in enabled_envs but no authenticator is configured.
          Set RailsHttpLab.config.authenticator to a callable ->(request) { ... } or remove :production from enabled_envs.
        MSG
      end
    end
  end
end
