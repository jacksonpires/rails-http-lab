ENV["RAILS_ENV"] ||= "development"

require "spec_helper"
require File.expand_path("dummy/config/environment", __dir__)
require "rspec/rails"
require "webmock/rspec"

# Storage points at a temp dir per example.
require "tmpdir"
require "fileutils"

module RailsHttpLabCsrfHelpers
  # Loads the SPA shell (which starts the session) and returns its
  # `csrf-token` meta as a header — exactly what the frontend sends.
  def csrf_headers
    @csrf_token ||= begin
      get "/rails/http-lab/"
      response.body[/<meta name="csrf-token" content="([^"]+)"/, 1] or
        raise "SPA shell has no csrf-token meta tag (status #{response.status})"
    end
    { "X-CSRF-Token" => @csrf_token }
  end
end

RSpec.configure do |c|
  c.include RailsHttpLabCsrfHelpers, type: :request

  # The engine verifies CSRF on every mutating endpoint; keep that on in
  # request specs regardless of the env the dummy app boots in.
  c.around(:each, type: :request) do |example|
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  c.before(:each, type: :request) do
    RailsHttpLab.reset_configuration!
    @rhl_tmp = Pathname.new(Dir.mktmpdir("rhl-spec-"))
    RailsHttpLab.configure do |cfg|
      cfg.storage_path = @rhl_tmp
      cfg.enabled_envs = %i[development test]
    end
    RailsHttpLab::Storage::Filesystem.new.ensure_root!
  end

  c.after(:each, type: :request) do
    FileUtils.rm_rf(@rhl_tmp) if @rhl_tmp
  end
end
