require 'rubygems'
require 'bundler'
Bundler.require
require 'cgi'
require 'yaml'

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
    assert string.match(/(W\/)?"([^"]|\\")*"/i), "Expected #{string} to be a valid ETag"
  end
end

String.infect_an_assertion :assert_is_etag, :must_be_etag, :only_one_argument

begin
  CONFIG = Hash[YAML.load_file('./config.yml').map{|(k,v)| [k.to_sym,v]}]
rescue Errno::ENOENT
  puts "Config file missing!\n\r".red
  puts "Please copy config.yml.example to config.yml and enter valid data.\n\r"
  exit 1
end

def default_headers
  @default_headers ||= { authorization: "Bearer #{CONFIG[:token]}" }
end

def do_network_request(path, options, &block)
  begin
    options[:base_url] = options[:base_url] || CONFIG[:storage_base_url]
    options[:url] = "#{options[:base_url]}/#{escape(path)}"
    options[:headers] = default_headers.merge(options[:headers] || {})

    RestClient::Request.execute(options, &block)
  rescue => e
    puts "#{options[:method]} request failed with: #{e.message}"
    e.response
  end
end

def do_put_request(path, data, headers={}, &block)
  begin
    RestClient.put "#{CONFIG[:storage_base_url]}/#{escape(path)}", data,
                   default_headers.merge(headers), &block
  rescue => e
    puts "PUT request failed with: #{e.message}"
    e.response
  end
end

def do_get_request(path, headers={}, &block)
  begin
    RestClient.get "#{CONFIG[:storage_base_url]}/#{escape(path)}",
                   default_headers.merge(headers), &block
  rescue => e
    puts "GET request failed with: #{e.message}".red
    e.response
  end
end

def do_delete_request(path, headers={}, &block)
  begin
    RestClient.delete "#{CONFIG[:storage_base_url]}/#{escape(path)}",
                      default_headers.merge(headers), &block
  rescue => e
    puts "DELETE request failed with: #{e.message}"
    e.response
  end
end

def do_head_request(path, headers={}, &block)
  begin
    RestClient.head "#{CONFIG[:storage_base_url]}/#{escape(path)}",
                    default_headers.merge(headers), &block
  rescue => e
    puts "HEAD request failed with: #{e.message}"
    e.response
  end
end

def do_options_request(path, headers={}, &block)
  begin
    RestClient.options "#{CONFIG[:storage_base_url]}/#{escape(path)}",
                    default_headers.merge(headers), &block
  rescue => e
    puts "OPTIONS request failed with: #{e.message}"
    e.response
  end
end

private

def escape(url)
  CGI::escape(url).gsub('+', '%20').gsub('%2F', '/')
end
