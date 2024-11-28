defmodule BrowserForge.Headers.UtilsTest do
  use ExUnit.Case, async: true
  alias BrowserForge.Headers.Utils

  describe "get_user_agent/1" do
    test "retrieves User-Agent with capitalized key" do
      headers = %{"User-Agent" => "Mozilla/5.0"}
      assert Utils.get_user_agent(headers) == "Mozilla/5.0"
    end

    test "retrieves User-Agent with lowercase key" do
      headers = %{"user-agent" => "Mozilla/5.0"}
      assert Utils.get_user_agent(headers) == "Mozilla/5.0"
    end

    test "returns nil when no User-Agent is present" do
      headers = %{"other" => "value"}
      assert Utils.get_user_agent(headers) == nil
    end
  end

  describe "get_browser/1" do
    test "detects Firefox" do
      assert Utils.get_browser("Mozilla/5.0 Firefox/100.0") == "firefox"
    end

    test "detects Chrome" do
      assert Utils.get_browser("Mozilla/5.0 Chrome/90.0") == "chrome"
    end

    test "detects Safari" do
      assert Utils.get_browser("Mozilla/5.0 Safari/605.1.15") == "safari"
    end

    test "detects Edge" do
      assert Utils.get_browser("Mozilla/5.0 Edge/91.0") == "edge"
    end

    test "returns nil for unknown browser" do
      assert Utils.get_browser("Unknown/1.0") == nil
    end
  end

  describe "pascalize/1" do
    test "keeps sec-ch-ua prefixed headers unchanged" do
      assert Utils.pascalize("sec-ch-ua-mobile") == "sec-ch-ua-mobile"
    end

    test "keeps colon prefixed headers unchanged" do
      assert Utils.pascalize(":authority") == ":authority"
    end

    test "uppercases special headers" do
      assert Utils.pascalize("dnt") == "DNT"
      assert Utils.pascalize("rtt") == "RTT"
      assert Utils.pascalize("ect") == "ECT"
    end

    test "capitalizes regular headers" do
      assert Utils.pascalize("accept") == "Accept"
      assert Utils.pascalize("content-type") == "Content-type"
    end
  end

  describe "pascalize_headers/1" do
    test "converts all header keys in map" do
      headers = %{
        "accept" => "*/*",
        "dnt" => "1",
        "sec-ch-ua" => "Chrome",
        ":path" => "/"
      }

      expected = %{
        "Accept" => "*/*",
        "DNT" => "1",
        "sec-ch-ua" => "Chrome",
        ":path" => "/"
      }

      assert Utils.pascalize_headers(headers) == expected
    end
  end

  describe "tuplify/1" do
    test "converts single value to tuple" do
      assert Utils.tuplify("test") == {"test"}
    end

    test "converts list to tuple" do
      assert Utils.tuplify(["a", "b"]) == {"a", "b"}
    end

    test "keeps existing tuple unchanged" do
      assert Utils.tuplify({"a", "b"}) == {"a", "b"}
    end

    test "handles nil" do
      assert Utils.tuplify(nil) == nil
    end
  end
end 
