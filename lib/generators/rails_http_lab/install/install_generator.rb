require "rails/generators"
require "rails/generators/base"

module RailsHttpLab
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs rails-http-lab: initializer, mount in routes, and docs/http-lab/ collection root."

      def copy_initializer
        template "initializer.rb.tt", "config/initializers/rails_http_lab.rb"
      end

      def mount_engine
        route_line = 'mount RailsHttpLab::Engine => RailsHttpLab.config.mount_path'
        routes_file = "config/routes.rb"
        if File.exist?(routes_file) && File.read(routes_file).include?(route_line)
          say_status :exist, "mount already present in #{routes_file}", :blue
        else
          route route_line
        end
      end

      def create_storage_root
        # Just the empty root. `bruno.json` and any subfolders
        # (environments/, collections, ...) are created lazily on first use
        # via Storage::Filesystem#ensure_root!.
        empty_directory "docs/http-lab"
      end

      def post_install_message
        say ""
        say "rails-http-lab installed.", :green
        say "Mounted at /rails/http-lab (configurable in config/initializers/rails_http_lab.rb)"
        say "Collections live in docs/http-lab/ (Bruno-compatible .bru files)"
        say ""
      end
    end
  end
end
