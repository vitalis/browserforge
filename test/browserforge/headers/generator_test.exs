defmodule BrowserForge.Headers.GeneratorTest do
  use ExUnit.Case, async: true
  alias BrowserForge.Headers.Generator
  alias BrowserForge.Headers.Browser

  describe "new/1" do
    test "creates a new generator with default options" do
      generator = Generator.new()
      assert %Generator{} = generator
      assert generator.options.http_version == "2"
      assert generator.options.browsers |> Enum.map(& &1.name) |> Enum.sort() == ["chrome", "edge", "firefox", "safari"]
    end

    test "creates a new generator with custom options" do
      generator = Generator.new(browser: "chrome", os: "windows", device: "desktop", http_version: "1")
      assert %Generator{} = generator
      assert generator.options.http_version == "1"
      assert [%Browser{name: "chrome"}] = generator.options.browsers
      assert generator.options.operating_systems == ["windows"]
      assert generator.options.devices == ["desktop"]
    end

    test "raises error for invalid HTTP version" do
      assert_raise ArgumentError, fn ->
        Generator.new(http_version: "3")
      end
    end
  end

  describe "generate/2" do
    setup do
      {:ok, generator: Generator.new()}
    end

    test "generates headers for Chrome", %{generator: generator} do
      headers = Generator.generate(generator, browser: "chrome", os: "windows", device: "desktop")
      assert headers["User-Agent"]
      assert headers["Accept"]
      assert headers["Accept-Language"]
      assert headers["Accept-Encoding"]
      assert headers["Sec-Ch-Ua"]
      assert headers["Sec-Ch-Ua-Mobile"] == "?0"
      assert headers["Sec-Ch-Ua-Platform"] == "\"Windows\""
    end

    test "generates headers for Firefox", %{generator: generator} do
      headers = Generator.generate(generator, browser: "firefox", os: "macos", device: "desktop")
      assert headers["User-Agent"]
      assert headers["Accept"]
      assert headers["Accept-Language"]
      assert headers["Accept-Encoding"]
      assert headers["Te"] == "trailers"
    end

    test "generates headers for Safari", %{generator: generator} do
      headers = Generator.generate(generator, browser: "safari", os: "macos", device: "desktop")
      assert headers["User-Agent"]
      assert headers["Accept"] == "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      assert headers["Accept-Language"]
      assert headers["Accept-Encoding"]
    end

    test "generates headers for Edge", %{generator: generator} do
      headers = Generator.generate(generator, browser: "edge", os: "windows", device: "desktop")
      assert headers["User-Agent"]
      assert headers["Accept"]
      assert headers["Accept-Language"]
      assert headers["Accept-Encoding"]
      assert headers["Sec-Ch-Ua"]
      assert headers["Sec-Ch-Ua-Mobile"] == "?0"
      assert headers["Sec-Ch-Ua-Platform"] == "\"Windows\""
    end

    test "generates HTTP/1 headers", %{generator: generator} do
      headers = Generator.generate(generator, browser: "chrome", http_version: "1")
      assert headers["Accept-Language"]  # Not accept-language (lowercase)
      assert headers["Sec-Fetch-Mode"]   # Not sec-fetch-mode (lowercase)
    end

    test "generates HTTP/2 headers", %{generator: generator} do
      headers = Generator.generate(generator, browser: "chrome", http_version: "2")
      assert headers["accept-language"]  # Lowercase
      assert headers["sec-fetch-mode"]   # Lowercase
    end

    test "handles multiple locales", %{generator: generator} do
      headers = Generator.generate(generator, locale: ["en-US", "fr-FR", "de-DE"])
      [first, second, third] = String.split(headers["Accept-Language"], ", ")
      assert first == "en-US"
      assert String.starts_with?(second, "fr-FR;q=0.")
      assert String.starts_with?(third, "de-DE;q=0.")
    end

    test "respects browser version constraints", %{generator: generator} do
      headers = Generator.generate(generator,
        browser: %Browser{name: "chrome", min_version: "90.0.0", max_version: "91.0.0"})
      [ua_brand | _] = Regex.scan(~r/v="(\d+)"/, headers["Sec-Ch-Ua"]) |> Enum.map(&List.last/1)
      version = String.to_integer(ua_brand)
      assert version >= 90 and version <= 91
    end

    test "handles mobile devices", %{generator: generator} do
      headers = Generator.generate(generator, browser: "chrome", device: "mobile")
      assert headers["Sec-Ch-Ua-Mobile"] == "?1"
    end

    test "merges request dependent headers", %{generator: generator} do
      custom_headers = %{"X-Custom" => "value"}
      headers = Generator.generate(generator, request_dependent_headers: custom_headers)
      assert headers["X-Custom"] == "value"
    end

    test "maintains header order", %{generator: generator} do
      headers = Generator.generate(generator, browser: "chrome")
      header_keys = Map.keys(headers)
      assert_header_order(header_keys, ["User-Agent", "Accept", "Accept-Language"])
    end
  end

  defp assert_header_order(header_keys, expected_order) do
    indices = Enum.map(expected_order, &Enum.find_index(header_keys, fn key -> key == &1 end))
    assert Enum.sort(indices) == indices, "Headers are not in expected order"
  end
end
