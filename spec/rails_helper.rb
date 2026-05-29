ENV["RAILS_ENV"] ||= "development"

require "spec_helper"
require File.expand_path("dummy/config/environment", __dir__)
require "rspec/rails"
require "webmock/rspec"

# Storage points at a temp dir per example.
require "tmpdir"
require "fileutils"

RSpec.configure do |c|
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
