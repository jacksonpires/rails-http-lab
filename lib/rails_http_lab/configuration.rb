module RailsHttpLab
  class Configuration
    attr_accessor :mount_path,
                  :storage_path,
                  :enabled_envs,
                  :authenticator,
                  :executor_timeout,
                  :executor_max_body

    def initialize
      @mount_path        = "/rails/http-lab"
      @storage_path      = nil
      @enabled_envs      = %i[development]
      @authenticator     = nil
      @executor_timeout  = 30
      @executor_max_body = 10 * 1024 * 1024
    end

    def resolved_storage_path
      @storage_path || default_storage_path
    end

    private

    def default_storage_path
      if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
        Rails.root.join("docs", "http-lab")
      else
        File.expand_path("docs/http-lab", Dir.pwd)
      end
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def config
      configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
