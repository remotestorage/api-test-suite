require 'rubygems'
require 'bundler'
Bundler.require

require 'minitest/spec'
require 'minitest/autorun'

require "minitest/reporters"
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Always run specs in the same order
class Minitest::Spec
  def self.test_order
    :sorted
  end
end

module MiniTest::Assertions
  def assert_is_etag(string)
    assert string.match(/"[0-9a-z]*"/i), "Expected #{string} to be a valid ETag"
  end
end

String.infect_an_assertion :assert_is_etag, :must_be_etag, :only_one_argument

CONFIG = {
  host: 'http://storage.5apps.dev',
  user: 'remotestorage-test',
  category: 'api-test'
}
# CONFIG = {
#   host: 'https://storage.5apps.com',
#   user: 'remotestorage-test',
#   category: 'api-test'
# }

BASE_URL = "#{CONFIG[:host]}/#{CONFIG[:user]}/#{CONFIG[:category]}/"
