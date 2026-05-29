require_relative "lib/rails_http_lab/version"

Gem::Specification.new do |spec|
  spec.name        = "rails-http-lab"
  spec.version     = RailsHttpLab::VERSION
  spec.authors     = ["Jackson Pires"]
  spec.email       = ["jackson@linkana.com"]
  spec.summary     = "In-app HTTP request lab for Rails, with Bruno-compatible storage."
  spec.description = "Mounts a Bruno-like UI inside your Rails app for ad-hoc HTTP requests, " \
                     "persisting collections as .bru files that are interchangeable with Bruno."
  spec.homepage    = "https://github.com/jacksonpires/rails-http-lab"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "source_code_uri"       => "https://github.com/jacksonpires/rails-http-lab",
    "bug_tracker_uri"       => "https://github.com/jacksonpires/rails-http-lab/issues",
    "rubygems_mfa_required" => "true",
    "allowed_push_host"     => "https://rubygems.org"
  }

  spec.files = Dir[
    "lib/**/*",
    "app/**/*",
    "config/**/*",
    "vendor/**/*",
    "README.md",
    "LICENSE.txt"
  ]

  spec.add_dependency "rails", ">= 7.0"
end
