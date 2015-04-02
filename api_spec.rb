require_relative "spec_helper"

describe "OPTIONS" do

  describe "GET" do
    it "returns a valid response" do
      res = RestClient.options(
        BASE_URL+"foo", {
          access_control_request_method: 'GET',
          origin: 'https://unhosted.org',
          referer: 'https://unhosted.org'
        }
      )

      res.code.must_equal 200

      res.headers[:access_control_allow_origin].must_equal 'https://unhosted.org'
      res.headers[:access_control_expose_headers].must_include 'ETag'

      ['GET', 'PUT', 'DELETE'].each do |verb|
        res.headers[:access_control_allow_methods].must_include verb
      end

      ['Authorization', 'Content-Type', 'Origin', 'If-Match', 'If-None-Match'].each do |header|
        res.headers[:access_control_allow_headers].must_include header
      end
    end
  end

end

describe "Requests" do

  describe "PUT a JSON object" do
    before do
      @res = RestClient.put BASE_URL+"test-object-simple.json",
             '{"foo": "bar"}',
             { content_type: "application/json" }
    end

    it "works" do
      [200, 201].must_include @res.code
      @res.headers[:etag].must_be_etag
    end
  end

  describe "GET a JSON object" do
    before do
      @res = RestClient.get BASE_URL+"test-object-simple.json"
    end

    it "works" do
      @res.code.must_equal 200
      @res.headers[:etag].must_be_etag
      @res.headers[:content_type].must_equal "application/json"
      @res.headers[:content_length].must_equal "14"
      @res.body.must_equal '{"foo": "bar"}'
    end
  end

  describe "PUT a JPG image" do
    before do
      @res = RestClient.put BASE_URL+"fuck-the-police.jpg",
             File.open("fixtures/files/fuck-the-police.jpg"),
             { content_type: "image/jpeg; charset=binary" }
    end

    it "works" do
      [200, 201].must_include @res.code
      @res.headers[:etag].must_be_etag
    end
  end

  describe "GET a JPG image" do
    before do
      @res = RestClient::Request.execute(method: :get, url: BASE_URL+"fuck-the-police.jpg", raw_response: true)
    end

    it "works" do
      @res.code.must_equal 200
      @res.headers[:etag].must_be_etag
      @res.headers[:content_type].must_equal "image/jpeg; charset=binary"
      @res.headers[:content_length].must_equal "28990"
      @res.to_s.must_equal File.read("fixtures/files/fuck-the-police.jpg")
    end
  end

  # TODO collision detection on PUT requests

end
