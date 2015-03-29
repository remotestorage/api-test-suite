require 'rubygems'
require 'bundler'
Bundler.require

require 'minitest/spec'
require 'minitest/autorun'
require 'purdytest'

require "minitest/reporters"
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

CONFIG = {
  host: 'https://storage.5apps.com',
  user: 'remotestorage-test',
  category: 'api-test'
}

BASE_URL = "#{CONFIG[:host]}/#{CONFIG[:user]}/#{CONFIG[:category]}"
