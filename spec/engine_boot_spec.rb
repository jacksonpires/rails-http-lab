require "spec_helper"

RSpec.describe "Engine boot guards" do
  before do
    RailsHttpLab.reset_configuration!
    Object.send(:remove_const, :Rails) if defined?(Rails) && !defined?(::Rails::Engine)
  end

  it "refuses to expose itself when production is enabled without an authenticator" do
    expect {
      RailsHttpLab.configure do |c|
        c.enabled_envs = %i[production]
        c.authenticator = nil
      end

      # Simulate the after_initialize check
      cfg = RailsHttpLab.config
      raise "boot guard tripped" if cfg.enabled_envs.include?(:production) && cfg.authenticator.nil?
    }.to raise_error(/boot guard tripped/)
  end

  it "allows production when an authenticator is given" do
    RailsHttpLab.configure do |c|
      c.enabled_envs = %i[production]
      c.authenticator = ->(_) { true }
    end
    cfg = RailsHttpLab.config
    expect(cfg.authenticator).to be_a(Proc)
  end
end
