source "https://rubygems.org"

gemspec

# CI matrix: RAILS_VERSION=7.2 bundle install && bundle exec rspec
if (rails_version = ENV["RAILS_VERSION"]) && !rails_version.empty?
  gem "rails", "~> #{rails_version}.0"
end

group :development, :test do
  gem "rspec", "~> 3.13"
  gem "rspec-rails", "~> 7.0"
  gem "webmock", "~> 3.23"
  gem "rack-test", "~> 2.1"
  gem "puma", "~> 6.4"
  gem "sprockets-rails", "~> 3.5"
end
