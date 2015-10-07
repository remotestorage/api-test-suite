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
      @res = do_put_request("#{CONFIG[:category]}/test-object-simple.json",
                            '{"new": "object"}',
                            { content_type: "application/json" })
    end

    it "works" do
      [200, 201].must_include @res.code
      @res.headers[:etag].wont_be_nil
      @res.headers[:etag].must_be_etag
    end
  end

  describe "PUT with nested folder" do
    before do
      @res = do_put_request("#{CONFIG[:category]}/some-subdir/nested-folder-object.json",
                            '{"foo": "baz"}',
                            { content_type: "application/json" })
    end

    it "works" do
      [200, 201].must_include @res.code
      @res.headers[:etag].wont_be_nil
      @res.headers[:etag].must_be_etag
    end
  end

  describe "PUT with same name as existing directory" do
    it "returns a 409" do
      do_put_request("#{CONFIG[:category]}/some-subdir", '', {content_type: "text/plain"}) do |res|
        res.code.must_equal 409
      end
    end
  end

  describe "PUT with same directory name as existing object" do
    before do
      do_put_request("#{CONFIG[:category]}/my-list", '', {content_type: "text/plain"})
    end

    it "returns a 409" do
      do_put_request("#{CONFIG[:category]}/my-list/item", '', {content_type: "text/plain"}) do |res|
        res.code.must_equal 409
      end
    end
  end

  describe "PUT with matching If-Match header" do
    before do
      @etag = do_head_request("#{CONFIG[:category]}/test-object-simple.json").headers[:etag]
      do_put_request("#{CONFIG[:category]}/test-object-simple.json", '{"foo": "bar"}',
                     { content_type: "application/json", if_match: @etag }) do |response|
         @res = response
       end
    end

    it "updates the object" do
      [200, 201].must_include @res.code
      @res.headers[:etag].wont_be_nil
      @res.headers[:etag].must_be_etag
    end
  end

  describe "PUT with non-matching If-Match header" do
    before do
      do_put_request("#{CONFIG[:category]}/test-object-simple.json",
                     '{"should": "not-happen"}',
                     { content_type: "application/json", if_match: %Q("invalid") }) do |response|
         @res = response
       end
    end

    it "returns 412" do
      @res.code.must_equal 412
    end
  end

  describe "PUT with If-Match header to non-existing object" do
    before do
      do_put_request("#{CONFIG[:category]}/four-oh-four.json",
                     '{"should": "not-happen"}',
                     { content_type: "application/json",
                       if_match: %Q("doesnotmatter") }) do |response|
         @res = response
       end
    end

    it "returns 412" do
      @res.code.must_equal 412
    end
  end

  describe "PUT with If-None-Match header to existing object" do
    before do
      do_put_request("#{CONFIG[:category]}/test-object-simple.json",
                     '{"should": "not-happen"}',
                     { content_type: "application/json",
                       if_none_match: "*" }) do |response|
         @res = response
       end
    end

    it "returns 412" do
      @res.code.must_equal 412
    end
  end

  describe "PUT with If-None-Match header to non-existing object" do
    before do
      do_put_request("#{CONFIG[:category]}/test-object-simple2.json",
                     '{"should": "happen"}',
                     { content_type: "application/json",
                       if_none_match: "*" }) do |response|
         @res = response
       end
    end

    it "works" do
      [200, 201].must_include @res.code
      @res.headers[:etag].wont_be_nil
      @res.headers[:etag].must_be_etag
    end
  end

  describe "GET a JSON object" do
    before do
      @res = do_get_request("#{CONFIG[:category]}/test-object-simple.json")
    end

    it "works" do
      @res.code.must_equal 200
      @res.headers[:etag].wont_be_nil
      @res.headers[:etag].must_be_etag
      @res.headers[:content_type].must_equal "application/json"
      @res.headers[:content_length].must_equal "14"
      @res.body.must_equal '{"foo": "bar"}'
    end
  end

  describe "GET with If-None-Match header" do
    before do
      @etag = do_head_request("#{CONFIG[:category]}/test-object-simple.json").headers[:etag]
      do_get_request("#{CONFIG[:category]}/test-object-simple.json", { if_none_match: @etag }) do |response|
        @res = response
      end
    end

    it "returns 304 with empty body when ETag matches" do
      @res.code.must_equal 304
      @res.body.must_be_empty
    end
  end

  describe "GET with multiple ETags in If-None-Match header" do
    before do
      @etag = do_head_request("#{CONFIG[:category]}/test-object-simple.json").headers[:etag]
      do_get_request("#{CONFIG[:category]}/test-object-simple.json",
                     { if_none_match: %Q("r2d2c3po", #{@etag}) }) do |response|
        @res = response
      end
    end

    it "returns 304 when one ETag matches" do
      @res.code.must_equal 304
      @res.body.must_be_empty
    end
  end

  describe "HEAD a JSON object" do
    before do
      @res = do_head_request("#{CONFIG[:category]}/test-object-simple.json")
    end

    it "works" do
      @res.code.must_equal 200
      @res.headers[:etag].wont_be_nil
      @res.headers[:etag].must_be_etag
      @res.headers[:content_type].must_equal "application/json"
      # Content-Length must match the correct length if present but it's optional
      @res.headers[:content_length].must_equal "14" if @res.headers[:content_length]
      @res.body.must_be_empty
    end
  end

  describe "PUT a JPG image" do
    before do
      @res = do_put_request("#{CONFIG[:category]}/Capture d'écran.jpg",
             File.open("fixtures/files/capture.jpg"),
             { content_type: "image/jpeg; charset=binary" })
    end

    it "works" do
      [200, 201].must_include @res.code
      @res.headers[:etag].wont_be_nil
      @res.headers[:etag].must_be_etag
    end
  end

  describe "GET a JPG image" do
    before do
      @res = do_network_request("#{CONFIG[:category]}/Capture d'écran.jpg", method: :get, raw_response: true)
    end

    it "works" do
      @res.code.must_equal 200
      @res.headers[:etag].wont_be_nil
      @res.headers[:etag].must_be_etag
      @res.headers[:content_type].must_equal "image/jpeg; charset=binary"
      @res.headers[:content_length].must_equal "28990"
      @res.to_s.must_equal File.read("fixtures/files/capture.jpg")
    end
  end

  describe "GET a non-existing object" do
    it "returns a 404" do
      do_get_request("#{CONFIG[:category]}/four-oh-four.html") do |response|
        response.code.must_equal 404
      end
    end
  end

  describe "HEAD directory listing" do
    before do
      @res = do_head_request("#{CONFIG[:category]}/")
    end

    it "works" do
      @res.code.must_equal 200
      @res.headers[:etag].must_be_etag
      @res.headers[:content_type].must_equal "application/json"
      @res.body.must_equal ""
    end
  end

  describe "GET directory listing" do
    before do
      @res = do_get_request("#{CONFIG[:category]}/")
      @listing = JSON.parse @res.body
    end

    it "works" do
      @res.code.must_equal 200
      @res.headers[:etag].must_be_etag
      @res.headers[:content_type].must_equal "application/json"

      @listing["@context"].must_equal "http://remotestorage.io/spec/folder-description"
      @listing["items"].each_pair do |key, value|
        key.must_be_kind_of String
        value["ETag"].must_be_kind_of String
        if key[-1] == "/"
          value.keys.must_equal ["ETag"]
        else
          value["Content-Length"].must_be_kind_of Integer
          value["Content-Type"].must_be_kind_of String
        end
      end
    end

    it "contains the correct items" do
      @listing["items"].length.must_equal 5
      ["Capture d'écran.jpg", "my-list", "some-subdir/",
       "test-object-simple.json", "test-object-simple2.json"].each do |key|
        @listing["items"].keys.must_include key
      end
    end
  end

  describe "HEAD directory listing for root" do
    before do
      @res = do_head_request("")
    end

    it "works" do
      @res.code.must_equal 200
      @res.headers[:etag].must_be_etag
      @res.headers[:content_type].must_equal "application/json"
      @res.body.must_equal ""
    end
  end

  describe "GET directory listing for root" do
    before do
      @res = do_get_request("")
      @listing = JSON.parse @res.body
    end

    it "works" do
      @res.code.must_equal 200
      @res.headers[:etag].must_be_etag
      @res.headers[:content_type].must_equal "application/json"

      @listing["@context"].must_equal "http://remotestorage.io/spec/folder-description"
      @listing["items"].each_pair do |key, value|
        key.must_be_kind_of String
        value["ETag"].must_be_kind_of String
        if key[-1] == "/"
          value.keys.must_equal ["ETag"]
        else
          value["Content-Length"].must_be_kind_of Integer
          value["Content-Type"].must_be_kind_of String
        end
      end
    end

    it "contains the correct items" do
      @listing["items"].keys.must_equal ["#{CONFIG[:category]}/"]
    end
  end

  describe "GET directory listing with If-None-Match header" do
    before do
      @etag = do_head_request("#{CONFIG[:category]}/").headers[:etag]
      do_get_request("#{CONFIG[:category]}/", { if_none_match: @etag }) do |response|
        @res = response
      end
    end

    it "returns 304 with empty body when ETag matches" do
      @res.code.must_equal 304
      @res.body.must_be_empty
    end
  end

  describe "GET directory listing with multiple ETags in If-None-Match header" do
    before do
      @etag = do_head_request("#{CONFIG[:category]}/").headers[:etag]
      do_get_request("#{CONFIG[:category]}/", { if_none_match: %Q("r2d2c3po", #{@etag}) }) do |response|
        @res = response
      end
    end

    it "returns 304 when one ETag matches" do
      @res.code.must_equal 304
      @res.body.must_be_empty
    end
  end

  describe "GET empty directory listing" do
    before do
      @res = do_get_request("#{CONFIG[:category]}/does-not-exist/")
      @listing = JSON.parse @res.body
    end

    it "works" do
      @res.code.must_equal 200

      @listing["@context"].must_equal "http://remotestorage.io/spec/folder-description"
      @listing["items"].must_equal({})
    end
  end

  describe "DELETE objects" do
    it "works" do
      [ "test-object-simple.json", "Capture d'écran.jpg",
        "some-subdir/nested-folder-object.json", "my-list" ].each do |key|
        res = do_delete_request("#{CONFIG[:category]}/#{key}")

        res.code.must_equal 200
        do_head_request("#{CONFIG[:category]}/#{key}") do |response|
          response.code.must_equal 404
        end
      end
    end
  end

  describe "DELETE a non-existing object" do
    it "returns a 404" do
      do_delete_request("#{CONFIG[:category]}/four-oh-four.html") do |response|
        response.code.must_equal 404
      end
    end
  end

  describe "DELETE with non-matching If-Match header" do
    before do
      do_delete_request("#{CONFIG[:category]}/test-object-simple2.json", {if_match: %Q("invalid")}) do |response|
        @res = response
      end
    end

    it "does not delete the object" do
      @res.code.must_equal 412

      do_head_request("#{CONFIG[:category]}/test-object-simple2.json") do |response|
        response.code.must_equal 200
      end
    end
  end

  describe "DELETE with matching If-Match header" do
    before do
      etag = do_head_request("#{CONFIG[:category]}/test-object-simple2.json").headers[:etag]
      @res = do_delete_request("#{CONFIG[:category]}/test-object-simple2.json", {if_match: etag})
    end

    it "deletes the object" do
      @res.code.must_equal 200

      do_head_request("#{CONFIG[:category]}/test-object-simple2.json") do |response|
        response.code.must_equal 404
      end
    end
  end

  describe "DELETE with If-Match header to non-existing object" do
    before do
      do_delete_request("#{CONFIG[:category]}/four-oh-four.json", {if_match: %Q("match me")}) do |response|
        @res = response
      end
    end

    it "returns 412" do
      @res.code.must_equal 412
    end
  end

end
