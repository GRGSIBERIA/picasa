# -*- encoding: utf-8 -*-
require "helper"

describe Picasa::Connection do
  before do
    @connection = Picasa::Connection.new(:user_id => "joe.doe")
  end

  describe "#inline_params" do
    it "converts params to inline style" do
      params = @connection.inline_params({:alt => "json", :kind => "photo"})
      # make ruby 1.8 tests pass
      assert_equal "alt=json", params.split("&").sort[0]
      assert_equal "kind=photo", params.split("&").sort[1]
    end

    it "changes param keys underscore to dash" do
      params = @connection.inline_params({:max_results => 10})
      assert_equal "max-results=10", params
    end

    it "escapes values" do
      params = @connection.inline_params({:kind => "żółć"})
      assert_equal "kind=%C5%BC%C3%B3%C5%82%C4%87", params
    end
  end

  describe "#path_with_params" do
    it "returns path when no params provided" do
      path = @connection.path_with_params("/data/feed/api")
      assert_equal "/data/feed/api", path
    end

    it "adds params to path" do
      path = @connection.path_with_params("/data/feed/api", {:q => "bomb"})
      assert_equal "/data/feed/api?q=bomb", path
    end
  end

  it "raises NotFound exception when 404 returned" do
    connection = Picasa::Connection.new(:user_id => "john.doe@domain.com")
    uri        = URI.parse("/data/feed/api/user/#{connection.user_id}/albumid/non-existing")

    stub_request(:get, "https://picasaweb.google.com" + uri.path).to_return(fixture("exceptions/not_found.txt"))

    assert_raises Picasa::NotFoundError, "Invalid entity id: non-existing" do
      connection.get(uri.path)
    end
  end

  it "raises PreconditionFailed exception when 412 returned" do
    connection = Picasa::Connection.new(:user_id => "john.doe@domain.com", :password => "secret")
    uri        = URI.parse("/data/feed/api/user/#{connection.user_id}/albumid/123")

    stub_request(:post, "https://www.google.com/accounts/ClientLogin").to_return(fixture("auth/success.txt"))
    stub_request(:delete, "https://picasaweb.google.com" + uri.path).to_return(fixture("exceptions/precondition_failed.txt"))

    assert_raises Picasa::PreconditionFailedError, "Mismatch: etags = [oldetag], version = [7]" do
      connection.delete(uri.path, {"If-Match" => "oldetag"})
    end
  end

  describe "authentication" do
    it "successfully authenticates" do
      connection = Picasa::Connection.new(:user_id => "john.doe@domain.com", :password => "secret")
      uri        = URI.parse("/data/feed/api/user/#{connection.user_id}")

      stub_request(:post, "https://www.google.com/accounts/ClientLogin").to_return(fixture("auth/success.txt"))
      stub_request(:get, "https://picasaweb.google.com/data/feed/api/user/john.doe@domain.com").to_return(fixture("album/album-list.txt"))

      connection.expects(:authenticate).returns(:result)
      refute_nil connection.get(uri.path)
    end

    it "raises an ResponseError when authentication failed" do
      connection = Picasa::Connection.new(:user_id => "john.doe@domain.com", :password => "secret")
      uri        = URI.parse("/data/feed/api/user/#{connection.user_id}")

      stub_request(:post, "https://www.google.com/accounts/ClientLogin").to_return(fixture("exceptions/forbidden.txt"))

      assert_raises(Picasa::ForbiddenError) do
        connection.get(uri.path)
      end
    end
  end
end
