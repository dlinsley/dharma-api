ruby '3.2.3'
source "https://rubygems.org"

gem 'mongoid'
gem 'mongoid_auto_increment_id'
gem 'log_buddy'
gem 'nokogiri'
gem 'sinatra'
gem 'thin'
gem 'mail'
gem 'rake'
gem 'rdiscount'
gem 'rack-cors'
gem 'newrelic_rpm'
gem 'bigdecimal', '~> 1.4'

group :development do
  require 'rbconfig'

  if RbConfig::CONFIG['target_os'] =~ /darwin/i
    gem 'rb-fsevent'
    gem 'growl'
  end

  if RbConfig::CONFIG['target_os'] =~ /linux/i
    gem 'rb-inotify'
    gem 'libnotify'
  end

  gem 'guard'
  gem 'guard-bundler'
  gem 'guard-rack'
  gem 'rspec'
end

group :test do
  gem 'rack-test'
end
