defmodule BrowserForge.Headers.UtilsTest do
  use ExUnit.Case, async: false
  doctest BrowserForge.Headers.Utils

  alias BrowserForge.Headers.Utils

  describe "get_user_agent/1" do
    test "gets User-Agent with pascal case" do
      headers = %{"User-Agent" => "Mozilla"}
      assert Utils.get_user_agent(headers) == "Mozilla"
    end

    test "gets user-agent with lower case" do
      headers = %{"user-agent" => "Chrome"}
      assert Utils.get_user_agent(headers) == "Chrome"
    end

    test "returns nil when no user agent" do
      assert Utils.get_user_agent(%{}) == nil
    end
  end

  describe "get_browser/1" do
    test "detects Firefox" do
      assert Utils.get_browser("Mozilla/5.0 Firefox/100.0") == "firefox"
    end

    test "detects Chrome" do
      assert Utils.get_browser("Chrome/90.0") == "chrome"
    end

    test "detects Safari" do
      assert Utils.get_browser("Safari/14.0") == "safari"
    end

    test "detects Edge" do
      assert Utils.get_browser("Edge/88.0") == "edge"
    end

    test "returns nil for unknown browser" do
      assert Utils.get_browser("Unknown Browser") == nil
    end
  end

  describe "pascalize/1" do
    test "handles special case headers" do
      assert Utils.pascalize("dnt") == "DNT"
      assert Utils.pascalize("rtt") == "RTT"
      assert Utils.pascalize("ect") == "ECT"
    end

    test "ignores pseudo headers" do
      assert Utils.pascalize(":authority") == ":authority"
    end

    test "ignores sec-ch-ua headers" do
      assert Utils.pascalize("sec-ch-ua-mobile") == "sec-ch-ua-mobile"
    end

    test "converts normal headers to pascal case" do
      assert Utils.pascalize("content-type") == "Content-Type"
      assert Utils.pascalize("accept-language") == "Accept-Language"
    end
  end

  describe "pascalize_headers/1" do
    test "converts all header names to pascal case" do
      headers = %{
        "content-type" => "text/plain",
        "dnt" => "1",
        ":authority" => "example.com"
      }

      expected = %{
        "Content-Type" => "text/plain",
        "DNT" => "1",
        ":authority" => "example.com"
      }

      assert Utils.pascalize_headers(headers) == expected
    end
  end

  describe "tuplify/1" do
    test "converts single value to tuple" do
      assert Utils.tuplify("value") == {"value"}
    end

    test "leaves lists unchanged" do
      assert Utils.tuplify(["a", "b"]) == ["a", "b"]
    end

    test "leaves nil unchanged" do
      assert Utils.tuplify(nil) == nil
    end
  end
end
