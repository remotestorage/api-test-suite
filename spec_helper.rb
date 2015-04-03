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
  category: 'api-test',
  token: 'rstoken'
}
# CONFIG = {
#   host: 'https://storage.5apps.com',
#   user: 'remotestorage-test',
#   category: 'api-test'
# }

BASE_URL = "#{CONFIG[:host]}/#{CONFIG[:user]}/#{CONFIG[:category]}/"

def default_headers
  @default_headers ||= { authorization: "Bearer #{CONFIG[:token]}" }
end

def do_network_request(path, options, &block)
  options[:headers] = default_headers.merge(options[:headers] || {})
  options[:url] = BASE_URL+path

  RestClient::Request.execute(options, &block)
end

def do_put_request(path, data, headers = {}, &block)
  RestClient.put "#{BASE_URL}#{path}", data, default_headers.merge(headers), &block
end

def do_get_request(path, headers = {}, &block)
  RestClient.get "#{BASE_URL}#{path}", default_headers.merge(headers), &block
end

def do_delete_request(path, headers = {}, &block)
  RestClient.delete "#{BASE_URL}#{path}", default_headers.merge(headers), &block
end

def do_head_request(path, headers = {}, &block)
  RestClient.head "#{BASE_URL}#{path}", default_headers.merge(headers), &block
end


