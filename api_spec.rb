require_relative "spec_helper"

def check_dir_listing_content_type(content_type)
  content_type.must_match(%r{application\/(ld\+)?json})
  if content_type != "application/ld+json"
    puts "WARNING: the content type \"#{content_type}\" works for directory listings, but the correct one to use is \"application/ld+json\"".yellow
  end
end

describe "OPTIONS" do

  describe "GET" do
    it "returns a valid response" do
      res = do_options_request CONFIG[:category]+"/foo", {
        access_control_request_method: 'GET',
        origin: 'https://unhosted.org',
        referer: 'https://unhosted.org'
      }

      res.code.must_equal 200
      res.headers[:access_control_allow_origin].must_match(/(\*|https:\/\/unhosted\.org)/)
      res.headers[:access_control_expose_headers].must_include 'ETag'
      res.headers[:access_control_allow_methods].must_include 'GET'

      ['Authorization', 'Content-Type', 'Origin', 'If-Match', 'If-None-Match'].each do |header|
        res.headers[:access_control_allow_headers].must_include header
      end
    end
  end

  describe "PUT and DELETE" do
    it "returns a valid response" do
      ["PUT", "DELETE"].each do |method|
        res = do_options_request CONFIG[:category]+"/foo", {
          access_control_request_method: method,
          origin: 'https://unhosted.org',
          referer: 'https://unhosted.org'
        }

        res.code.must_equal 200
        res.headers[:access_control_allow_origin].must_equal "https://unhosted.org"
        res.headers[:access_control_expose_headers].must_include 'ETag'
        res.headers[:access_control_allow_methods].must_include method

        ['Authorization', 'Content-Type', 'Origin', 'If-Match', 'If-None-Match'].each do |header|
          res.headers[:access_control_allow_headers].must_include header
        end
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

  describe "PUT a JSON object" do
    before do
      @old_outer_listing_res = do_get_request("#{CONFIG[:category]}/")
      @old_listing_res = do_get_request("#{CONFIG[:category]}/some-other-subdir/")
      @res = do_put_request("#{CONFIG[:category]}/some-other-subdir/test-object-simple.json",
                            '{"new": "object"}',
                            { content_type: "application/json" })
      @outer_listing_res = do_get_request("#{CONFIG[:category]}/")
      @listing_res = do_get_request("#{CONFIG[:category]}/some-other-subdir/")

      @item_etag = @res.headers[:etag]
      @old_listing = JSON.parse @old_listing_res.body
      @listing = JSON.parse @listing_res.body
      @item_info = @listing["items"]["test-object-simple.json"]
      @old_item_info = @old_listing["items"]["test-object-simple.json"]
    end

    it "works" do
      [200, 201].must_include @res.code
      @item_etag.wont_be_nil
      @item_etag.must_be_etag
    end

    it "updates the file etag in the listing" do
      @item_info["ETag"].must_equal @item_etag.delete('"')
      @item_info["ETag"].wont_equal @old_item_info["ETag"]
    end

    it "updates the folder etag" do
      @listing_res.headers[:etag].wont_equal @old_outer_listing_res.headers[:etag]
      @outer_listing_res.headers[:etag].wont_equal @old_outer_listing_res.headers[:etag]
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
      @res.headers[:expires].must_equal "0"
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
      check_dir_listing_content_type(@res.headers[:content_type])
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
      check_dir_listing_content_type(@res.headers[:content_type])

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
      @listing["items"].length.must_equal 6
      ["Capture d'écran.jpg", "my-list", "some-subdir/", "some-other-subdir/",
       "test-object-simple.json", "test-object-simple2.json"].each do |key|
        @listing["items"].keys.must_include key
      end
    end
  end

  describe "PUT a JSON object to root dir" do
    it "fails with normal token" do
      res = do_put_request("thisisbadpractice.json", '{"new": "object"}',
                            { content_type: "application/json" })

      [401, 403].must_include res.code
    end

    it "works with root token" do
      res = do_put_request("thisisbadpractice.json", '{"new": "object"}',
                            { content_type: "application/json",
                              authorization: "Bearer #{CONFIG[:root_token]}"})

      [200, 201].must_include res.code
      res.headers[:etag].wont_be_nil
      res.headers[:etag].must_be_etag
    end
  end

  describe "HEAD directory listing of root dir" do
    before do
      @res = do_head_request("", {authorization: "Bearer #{CONFIG[:root_token]}"})
    end

    it "works" do
      @res.code.must_equal 200
      @res.headers[:etag].must_be_etag
      check_dir_listing_content_type(@res.headers[:content_type])
      @res.body.must_equal ""
    end
  end

  describe "GET directory listing of root dir" do
    before do
      @res = do_get_request("", {authorization: "Bearer #{CONFIG[:root_token]}"})
      @listing = JSON.parse @res.body
    end

    it "works" do
      @res.code.must_equal 200
      @res.headers[:etag].must_be_etag
      check_dir_listing_content_type(@res.headers[:content_type])

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
      @listing["items"].keys.must_equal ["#{CONFIG[:category]}/",
                                         "thisisbadpractice.json"]
    end
  end

  describe "DELETE object in root dir" do
    it "works" do
      res = do_delete_request("thisisbadpractice.json",
                              {authorization: "Bearer #{CONFIG[:root_token]}"})

      res.code.must_equal 200
      do_head_request("thisisbadpractice.json", {authorization: "Bearer #{CONFIG[:root_token]}"}) do |response|
        response.code.must_equal 404
      end
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

  describe "using base URL of a different user" do

    it "should fail" do
      ["GET", "PUT", "DELETE"].each do |method|
        res = do_network_request("#{CONFIG[:category]}/failwhale.png",
                                 method: method,
                                 base_url: CONFIG[:storage_base_url_other])

        [401, 403].must_include res.code
      end
    end

  end

  describe "using a read-only token" do

    describe "GET" do
      it "works" do
        res = do_get_request("#{CONFIG[:category]}/test-object-simple.json",
                             authorization: "Bearer #{CONFIG[:read_only_token]}")

        res.code.must_equal 200
      end
    end

    describe "HEAD" do
      it "works" do
        res = do_head_request("#{CONFIG[:category]}/test-object-simple.json",
                              authorization: "Bearer #{CONFIG[:read_only_token]}")

        res.code.must_equal 200
      end
    end

    describe "PUT" do
      it "fails" do
        res = do_put_request("#{CONFIG[:category]}/test-object-simple-test.json",
                             '{"new": "object"}',
                             { content_type: "application/json",
                               authorization: "Bearer #{CONFIG[:read_only_token]}" })

        [401, 403].must_include res.code
      end
    end

    describe "DELETE" do
      it "fails" do
        res = do_delete_request("#{CONFIG[:category]}/test-object-simple.json",
                                authorization: "Bearer #{CONFIG[:read_only_token]}")

        [401, 403].must_include res.code
      end
    end

  end

  describe "in a public folder" do

    describe "PUT with a read/write category token" do
      it "works" do
        res = do_put_request("public/#{CONFIG[:category]}/test-object-simple.json",
                             '{"new": "object"}',
                             { content_type: "application/json" })

        [200, 201].must_include res.code
      end
    end

    describe "PUT with a read/write category token to wrong category" do
      it "fails" do
        res = do_put_request("public/othercategory/test-object-simple.json",
                             '{"new": "object"}',
                             { content_type: "application/json" })

        [401, 403].must_include res.code
      end
    end

    describe "GET without a token" do
      it "works" do
        res = do_get_request("public/#{CONFIG[:category]}/test-object-simple.json",
                             authorization: nil)

        res.code.must_equal 200
      end
    end

    describe "HEAD without a token" do
      it "works" do
        res = do_head_request("public/#{CONFIG[:category]}/test-object-simple.json",
                              authorization: nil)

        res.code.must_equal 200
      end
    end

    describe "PUT without a token" do
      it "is not allowed" do
        res = do_put_request("public/#{CONFIG[:category]}/test-object-simple-test.json",
                             '{"new": "object"}',
                             { content_type: "application/json",
                               authorization: nil })

        [401, 403].must_include res.code
      end
    end

    describe "GET directory listing without a token" do
      it "is not allowed" do
        res = do_get_request("public/#{CONFIG[:category]}/", authorization: nil)

        [401, 403].must_include res.code
      end

      it "doesn't expose if folder is empty" do
        res = do_get_request("public/#{CONFIG[:category]}/", authorization: nil)
        res2 = do_get_request("public/#{CONFIG[:category]}/foo/", authorization: nil)

        res.code.must_equal res2.code
        res.headers.must_equal res2.headers
        res.body.must_equal res2.body
      end
    end

    describe "GET directory listing with a read-write category token" do
      it "works" do
        res = do_get_request("public/#{CONFIG[:category]}/")

        res.code.must_equal 200
      end
    end

    describe "DELETE without a token" do
      it "is not allowed" do
        res = do_delete_request("public/#{CONFIG[:category]}/test-object-simple.json",
                                authorization: nil)

        [401, 403].must_include res.code
      end
    end

    describe "DELETE with a read/write category token" do
      it "works" do
        res = do_delete_request("public/#{CONFIG[:category]}/test-object-simple.json")

        res.code.must_equal 200
      end
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
