require_relative "spec_helper"

def check_dir_listing_content_type(content_type)
  content_type.must_match(%r{application\/(ld\+)?json})
  if content_type != "application/ld+json"
    puts "WARNING: the content type \"#{content_type}\" works for directory listings, but the correct one to use is \"application/ld+json\"".yellow
  end
end

def check_dir_listing(listing)
  listing["@context"].must_equal "http://remotestorage.io/spec/folder-description"
  listing["items"].each_pair do |key, value|
    key.must_be_kind_of String
    value["ETag"].must_be_kind_of String
    if key[-1] == "/"
      value.keys.must_equal ["ETag"]
      refute listing["items"].key?(key.chomp("/")), "Both #{key} and a document with the same name" if DRAFT && DRAFT >= 12
    else
      value["Content-Length"].must_be_kind_of Integer
      value["Content-Type"].must_be_kind_of String
      if DRAFT && DRAFT >= 11
        modified = value["Last-Modified"]
        modified.must_be_kind_of String
        begin
          Time.httpdate(modified)
        rescue ArgumentError
          flunk "Invalid Last-Modified HTTP-date for #{key}: #{modified.inspect}"
        end
      end
    end
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

      [200, 204].must_include res.code
      ["*", "https://unhosted.org"].must_include res.headers[:access_control_allow_origin]
      res.headers[:access_control_expose_headers].to_s.downcase.split(',').map(&:strip).must_include 'etag'
      res.headers[:access_control_allow_methods].to_s.split(',').map(&:strip).must_include 'GET'
      res.body.must_be_empty

      ['Authorization', 'Content-Type', 'Origin', 'If-Match', 'If-None-Match'].each do |header|
        res.headers[:access_control_allow_headers].to_s.downcase.split(',').map(&:strip).must_include header.downcase
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

        [200, 204].must_include res.code
        origins = ["https://unhosted.org"]
        origins << "*" if DRAFT && DRAFT >= 6
        origins.must_include res.headers[:access_control_allow_origin]
        res.headers[:access_control_expose_headers].to_s.downcase.split(',').map(&:strip).must_include 'etag'
        res.headers[:access_control_allow_methods].to_s.split(',').map(&:strip).must_include method
        res.body.must_be_empty

        ['Authorization', 'Content-Type', 'Origin', 'If-Match', 'If-None-Match'].each do |header|
          res.headers[:access_control_allow_headers].to_s.downcase.split(',').map(&:strip).must_include header.downcase
        end
      end
    end
  end

end

describe "Requests" do

  describe "PUT a JSON object" do
    before do
      @res = do_put_request("#{CONFIG[:category]}/test-object-simple.json",
                            '{"new": "object", "should_be": "large_enough", "to_trigger": "compression", "if_enabled": "on_server"}',
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

  describe "updating that JSON object" do
    before do
      @old_outer_listing_res = do_get_request("#{CONFIG[:category]}/")
      @old_listing_res = do_get_request("#{CONFIG[:category]}/some-subdir/")
      old_listing = JSON.parse @old_listing_res.body
      @old_item_info = old_listing["items"]["nested-folder-object.json"]

      @res = do_put_request("#{CONFIG[:category]}/some-subdir/nested-folder-object.json",
                            '{"foo": "bam"}',
                            { content_type: "application/json" })
      @item_etag = @res.headers[:etag]

      @outer_listing_res = do_get_request("#{CONFIG[:category]}/")
      @listing_res = do_get_request("#{CONFIG[:category]}/some-subdir/")
      listing = JSON.parse @listing_res.body
      @item_info = listing["items"]["nested-folder-object.json"]
    end

    it "works" do
      # before runs for each block once, so we have to put all blocks into one
      [200, 201].must_include @res.code
      @item_etag.wont_be_nil
      @item_etag.must_be_etag

      # updates the file etags in the folder listing
      @item_info["ETag"].must_equal @item_etag.delete('"')
      @item_info["ETag"].wont_equal @old_item_info["ETag"]

      # updates the folder etag
      @listing_res.headers[:etag].wont_equal @old_listing_res.headers[:etag]
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

  describe "PUT with Content-Range" do
    it "returns a 400" do
      skip "Content-Range PUT rule starts at draft 06" if DRAFT && DRAFT < 6
      # https://tools.ietf.org/html/rfc7231#section-4.3.4
      do_put_request("#{CONFIG[:category]}/some-subdir/nested-folder-object.json",
                     'sup', {content_range: "bytes 0-2/6", content_type: "text/plain"}) do |res|
        res.code.must_equal 400
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
      do_put_request("#{CONFIG[:category]}/test-object-simple.json",
                     '{"new": "object", "should_be": "large_enough", "to_trigger": "compression", "if_enabled": "on_server"}',
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
                     '{"new": "object", "should_be": "large_enough", "to_trigger": "compression", "if_enabled": "on_server"}',
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
      @res.headers[:content_length].must_equal "102"
      check_cache_headers(@res)
      @res.body.must_equal '{"new": "object", "should_be": "large_enough", "to_trigger": "compression", "if_enabled": "on_server"}'
    end
  end

  describe "advertised byte ranges" do
    it "returns the requested bytes and identifies an unsatisfiable range" do
      skip "Range advertisement starts at draft 06" unless DRAFT && DRAFT >= 6
      path = "#{CONFIG[:category]}/test-object-simple.json"
      full = do_get_request(path)
      full.code.must_equal 200
      advertised = STORAGE_LINK && STORAGE_LINK.fetch('properties')[DraftProfile::RANGE] == 'GET'
      unless advertised || full.headers[:accept_ranges].to_s.downcase.split(',').map(&:strip).include?('bytes')
        skip "Server does not advertise byte ranges"
      end
      size = full.body.bytesize
      part = do_get_request(path, range: 'bytes=1-3')
      part.code.must_equal 206
      part.headers[:content_range].must_equal "bytes 1-3/#{size}"
      part.body.must_equal full.body.byteslice(1, 3)
      do_get_request(path, range: "bytes=#{size}-") { |res| res.code.must_equal 416 }
    end
  end

  describe "GET a JSON object while accepting compressed content" do
    before do
      @res = do_get_request("#{CONFIG[:category]}/test-object-simple.json",
                            { accept_encoding: 'gzip, deflate, br' })
    end

    it "works" do
      @res.code.must_equal 200
      @res.headers[:content_encoding].must_be_nil
      @res.headers[:etag].wont_be_nil
      @res.headers[:etag].must_be_etag
      @res.headers[:content_type].must_equal "application/json"
      @res.headers[:content_length].must_equal "102"
      check_cache_headers(@res)
      @res.body.must_equal '{"new": "object", "should_be": "large_enough", "to_trigger": "compression", "if_enabled": "on_server"}'
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
      [200, 204].must_include @res.code
      @res.headers[:etag].wont_be_nil
      @res.headers[:etag].must_be_etag
      @res.headers[:content_type].must_equal "application/json"
      # Content-Length must match the correct length if present but it's optional
      @res.headers[:content_length].must_equal "102" if @res.headers[:content_length]
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
      [200, 204].must_include @res.code
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
      check_cache_headers(@res) if DRAFT

      check_dir_listing(@listing)
    end

    it "contains the correct items" do
      @listing["items"].length.must_equal 5
      ["Capture d'écran.jpg", "my-list", "some-subdir/",
       "test-object-simple.json", "test-object-simple2.json"].each do |key|
        @listing["items"].keys.must_include key
      end
    end
  end

  describe "PUT a JSON object to root dir" do
    it "fails with normal token" do
      res = do_put_request("thisisbadpractice.json", '{"new": "object"}',
                            { content_type: "application/json" })

      check_denied(res, 403)
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
      [200, 204].must_include @res.code
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
      check_cache_headers(@res) if DRAFT

      check_dir_listing(@listing)
    end

    it "contains the correct items" do
      @listing["items"].keys.must_include "#{CONFIG[:category]}/"
      @listing["items"].keys.must_include "thisisbadpractice.json"
      @listing["items"].count.must_equal 2
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

        [200, 204].must_include res.code
        res.body.must_be_empty
      end
    end

    describe "PUT" do
      it "fails" do
        res = do_put_request("#{CONFIG[:category]}/test-object-simple-test.json",
                             '{"new": "object"}',
                             { content_type: "application/json",
                               authorization: "Bearer #{CONFIG[:read_only_token]}" })

        check_denied(res, 403)
      end
    end

    describe "DELETE" do
      it "fails" do
        res = do_delete_request("#{CONFIG[:category]}/test-object-simple.json",
                                authorization: "Bearer #{CONFIG[:read_only_token]}")

        check_denied(res, 403)
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

        check_denied(res, 403)
      end
    end

    describe "GET without a token" do
      it "works" do
        res = do_get_request("public/#{CONFIG[:category]}/test-object-simple.json",
                             authorization: nil)

        res.code.must_equal 200
        check_cache_headers(res, public_path: true) if DRAFT
      end
    end

    describe "HEAD without a token" do
      it "works" do
        skip "Anonymous HEAD starts at draft 06" if DRAFT && DRAFT < 6
        res = do_head_request("public/#{CONFIG[:category]}/test-object-simple.json",
                              authorization: nil)

        [200, 204].must_include res.code
        res.body.must_be_empty
      end
    end

    describe "PUT without a token" do
      it "is not allowed" do
        res = do_put_request("public/#{CONFIG[:category]}/test-object-simple-test.json",
                             '{"new": "object"}',
                             { content_type: "application/json",
                               authorization: nil })

        check_denied(res, 401)
      end
    end

    describe "GET directory listing without a token" do
      it "is not allowed" do
        res = do_get_request("public/#{CONFIG[:category]}/", authorization: nil)

        check_denied(res, 401)
      end

      it "doesn't expose if folder is empty" do
        res = do_get_request("public/#{CONFIG[:category]}/", authorization: nil)
        res2 = do_get_request("public/#{CONFIG[:category]}/foo/", authorization: nil)

        res.code.must_equal res2.code
        [:content_type, :content_length, :www_authenticate, :etag].each do |header|
          assert_equal res.headers[header], res2.headers[header]
        end
        res.body.must_equal res2.body
      end
    end

    describe "GET directory listing with a read-write category token" do
      it "works" do
        res = do_get_request("public/#{CONFIG[:category]}/")

        res.code.must_equal 200
        check_cache_headers(res, public_path: true) if DRAFT
      end
    end

    describe "DELETE without a token" do
      it "is not allowed" do
        res = do_delete_request("public/#{CONFIG[:category]}/test-object-simple.json",
                                authorization: nil)

        check_denied(res, 401)
      end
    end

    describe "DELETE with a read/write category token" do
      it "works" do
        res = do_delete_request("public/#{CONFIG[:category]}/test-object-simple.json")

        [200, 204].must_include res.code
      end
    end
  end

  describe "DELETE objects" do
    it "works" do
      [ "test-object-simple.json", "Capture d'écran.jpg",
        "some-subdir/nested-folder-object.json", "my-list" ].each do |key|
        res = do_delete_request("#{CONFIG[:category]}/#{key}")

        [200, 204].must_include res.code
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
      [200, 204].must_include @res.code

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

describe "WebFinger" do
  it "advertises the storage API for the selected draft" do
    skip "Set webfinger_url to check discovery" unless STORAGE_LINK
    expected_rel = DRAFT >= 5 ? DraftProfile::REL : 'remotestorage'
    STORAGE_LINK['rel'].must_equal expected_rel
    STORAGE_LINK.fetch('properties')[DraftProfile::VERSION].must_equal("draft-dejong-remotestorage-%02d" % DRAFT)
  end

  it "advertises both OAuth endpoints and S256 when it offers PKCE" do
    skip "PKCE discovery starts at draft 26" unless DRAFT && DRAFT >= 26
    skip "Set webfinger_url to check discovery" unless STORAGE_LINK
    DraftProfile.validate_pkce!(STORAGE_LINK.fetch('properties'))
  end
end
