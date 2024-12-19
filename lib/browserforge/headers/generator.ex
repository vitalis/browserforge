defmodule BrowserForge.Headers.Generator do
  @moduledoc """
  Generates HTTP headers based on a set of constraints.
  """

  alias BrowserForge.Headers.Browser
  alias BrowserForge.Headers.HttpBrowserObject
  alias BrowserForge.Headers.Utils
  alias BrowserForge.BayesianNetwork

  @supported_browsers ~w(chrome firefox safari edge)
  @supported_operating_systems ~w(windows macos linux android ios)
  @supported_devices ~w(desktop mobile)
  @supported_http_versions ~w(1 2)
  @missing_value_dataset_token "*MISSING_VALUE*"
  @data_dir Application.compile_env(
              :browserforge,
              :headers_data_dir,
              Path.join(:code.priv_dir(:browserforge), "headers/data")
            )
  @relaxation_order ~w(locales devices operatingSystems browsers)

  @http1_sec_fetch_attributes %{
    "Sec-Fetch-Mode" => "same-site",
    "Sec-Fetch-Dest" => "navigate",
    "Sec-Fetch-Site" => "?1",
    "Sec-Fetch-User" => "document"
  }

  @http2_sec_fetch_attributes %{
    "sec-fetch-mode" => "same-site",
    "sec-fetch-dest" => "navigate",
    "sec-fetch-site" => "?1",
    "sec-fetch-user" => "document"
  }

  # Initialize paths and data at compile time
  @browser_helper_path Path.join(@data_dir, "browser-helper-file.json")
  @headers_order_path Path.join(@data_dir, "headers-order.json")
  @browser_helper_data Jason.decode!(File.read!(@browser_helper_path))
  @headers_order Jason.decode!(File.read!(@headers_order_path))

  # Initialize unique browsers at compile time
  @unique_browsers (for browser <- @browser_helper_data,
                       browser != @missing_value_dataset_token,
                       [browser_string, http_version] = String.split(browser, "|"),
                       browser_string != @missing_value_dataset_token,
                       [browser_name, version_string] = String.split(browser_string, "/"),
                       version =
                         version_string
                         |> String.split(".")
                         |> Enum.map(&String.to_integer/1)
                         |> List.to_tuple() do
                     %HttpBrowserObject{
                       name: browser_name,
                       version: version,
                       complete_string: browser,
                       http_version: http_version
                     }
                   end)

  @type browser_option :: String.t() | Browser.t()
  @type list_or_string :: String.t() | [String.t()]

  @type t :: %__MODULE__{
          options: map(),
          unique_browsers: list(),
          headers_order: map(),
          input_generator_network: BayesianNetwork.t(),
          header_generator_network: BayesianNetwork.t()
        }

  defstruct [
    :options,
    :unique_browsers,
    :headers_order,
    :input_generator_network,
    :header_generator_network
  ]

  @doc """
  Creates a new HeaderGenerator with the given options.

  ## Options
    * `:browser` - Browser(s) or Browser struct(s) to generate headers for
    * `:os` - Operating system(s) to generate headers for
    * `:device` - Device(s) to generate headers for
    * `:locale` - Language(s) for the Accept-Language header
    * `:http_version` - HTTP version to use (1 or 2)
    * `:strict` - Whether to throw an error if headers cannot be generated

  ## Examples
      iex> Generator.new()
      %Generator{}

      iex> Generator.new(browser: "chrome", os: "windows", device: "desktop")
      %Generator{}
  """
  def new(opts \\ []) do
    http_version = to_string(Keyword.get(opts, :http_version, "2"))

    unless http_version in @supported_http_versions do
      raise ArgumentError,
            "HTTP version #{http_version} is not supported. Supported versions are: #{inspect(@supported_http_versions)}"
    end

    browsers = prepare_browsers_config(opts[:browser] || @supported_browsers, http_version)

    options = %{
      browsers: browsers,
      operating_systems: List.wrap(opts[:os] || @supported_operating_systems),
      devices: List.wrap(opts[:device] || @supported_devices),
      locales: List.wrap(opts[:locale] || "en-US"),
      http_version: http_version,
      strict: Keyword.get(opts, :strict, false)
    }

    input_network = BayesianNetwork.new(Path.join(@data_dir, "input-network.zip"))
    header_network = BayesianNetwork.new(Path.join(@data_dir, "header-network.zip"))

    %__MODULE__{
      options: options,
      unique_browsers: @unique_browsers,
      headers_order: @headers_order,
      input_generator_network: input_network,
      header_generator_network: header_network
    }
  end

  @doc """
  Generates headers using the default options and their possible overrides.

  ## Options
    * `:browser` - Browser(s) or Browser struct(s) to generate headers for
    * `:os` - Operating system(s) to generate headers for
    * `:device` - Device(s) to generate headers for
    * `:locale` - Language(s) for the Accept-Language header
    * `:http_version` - HTTP version to use (1 or 2)
    * `:user_agent` - User-Agent(s) to use
    * `:request_dependent_headers` - Known values of request-dependent headers
    * `:strict` - Whether to throw an error if headers cannot be generated

  ## Examples
      iex> generator = Generator.new()
      iex> Generator.generate(generator)
      %{"User-Agent" => "...", ...}

      iex> Generator.generate(generator, browser: "chrome", os: "windows")
      %{"User-Agent" => "...", ...}
  """
  def generate(generator, opts \\ []) do
    options = %{
      browsers:
        prepare_browsers_config(
          opts[:browser] || @supported_browsers,
          to_string(opts[:http_version] || "2")
        ),
      operating_systems: List.wrap(opts[:os] || @supported_operating_systems),
      devices: List.wrap(opts[:device] || @supported_devices),
      locales: List.wrap(opts[:locale] || "en-US"),
      http_version: to_string(opts[:http_version] || "2"),
      strict: opts[:strict] || false,
      user_agent: opts[:user_agent],
      request_dependent_headers: opts[:request_dependent_headers]
    }

    # Filter out nil values
    options = for {k, v} <- options, not is_nil(v), into: %{}, do: {k, v}

    generated = get_headers(generator, options)

    if (options[:http_version] || generator.options.http_version) == "2" do
      pascalize_headers(generated)
    else
      generated
    end
  end

  defp get_headers(generator, options, retry_count \\ 0) do
    if retry_count > 3 do
      raise "Failed to generate headers after 3 retries. Please try with different options."
    end

    request_dependent_headers = options[:request_dependent_headers] || %{}
    user_agent = options[:user_agent]

    # Process new options
    header_options =
      if Map.has_key?(options, :browsers) ||
           (Map.has_key?(options, :http_version) &&
              options.http_version != generator.options.http_version) do
        update_http_version(generator.options, options)
      else
        Map.merge(generator.options, options)
      end

    possible_attribute_values = get_possible_attribute_values(header_options)

    {http1_values, http2_values} =
      if user_agent do
        user_agents = List.wrap(user_agent)
        http1 = BayesianNetwork.get_possible_values(generator.header_generator_network, %{"User-Agent" => user_agents})
        http2 = BayesianNetwork.get_possible_values(generator.header_generator_network, %{"user-agent" => user_agents})
        {http1, http2}
      else
        {%{}, %{}}
      end

    constraints = prepare_constraints(possible_attribute_values, http1_values, http2_values)

    case BayesianNetwork.generate_consistent_sample_when_possible(generator.input_generator_network, constraints) do
      nil ->
        cond do
          header_options.http_version == "1" ->
            new_opts = Map.put(options, :http_version, "2")
            headers = get_headers(generator, new_opts, retry_count + 1)
            order_headers(pascalize_headers(headers), generator.headers_order)

          relaxation_index = Enum.find_index(@relaxation_order, &(to_string(&1) in Map.keys(options))) ->
            if header_options.strict do
              raise "No headers based on this input can be generated. Please relax or change some of the requirements you specified."
            end

            key_to_remove = @relaxation_order |> Enum.at(relaxation_index) |> to_string()
            relaxed_options = Map.delete(options, key_to_remove)
            get_headers(generator, relaxed_options, retry_count + 1)

          true ->
            if header_options.strict do
              raise "No headers based on this input can be generated. Please relax or change some of the requirements you specified."
            end
            get_headers(generator, options, retry_count + 1)
        end

      input_sample ->
        generated_sample = BayesianNetwork.generate_sample(generator.header_generator_network, input_sample)
        generated_http_and_browser = prepare_http_browser_object(generated_sample["*BROWSER_HTTP"])

        # Get browser-specific headers
        browser_headers = get_browser_specific_headers(generated_http_and_browser, input_sample)
        generated_sample = Map.merge(generated_sample, browser_headers)

        # Add Accept-Language header
        accept_language_field_name =
          if HttpBrowserObject.is_http2(generated_http_and_browser),
            do: "accept-language",
            else: "Accept-Language"

        generated_sample =
          Map.put(
            generated_sample,
            accept_language_field_name,
            get_accept_language_header(header_options.locales)
          )

        # Remove connection, close, missing value headers, and normalize casing
        final_headers =
          generated_sample
          |> Enum.reject(fn {k, v} ->
            String.starts_with?(k, "*") or
            (String.downcase(k) == "connection" and v == "close") or
            v == @missing_value_dataset_token
          end)
          |> Enum.map(fn {k, v} -> {String.downcase(k), v} end)  # First normalize all to lowercase
          |> Enum.group_by(  # Group by lowercase key to handle duplicates
            fn {k, _} -> k end,
            fn {_, v} -> v end
          )
          |> Enum.map(fn {k, vs} -> {k, List.first(vs)} end)  # Take first value of duplicates
          |> Map.new()
          |> Map.merge(request_dependent_headers)
          |> normalize_headers(HttpBrowserObject.is_http2(generated_http_and_browser))
          |> order_headers(generator.headers_order)

        final_headers
    end
  end

  defp normalize_headers(headers, is_http2) do
    if is_http2 do
      headers
    else
      headers
      |> Enum.map(fn {k, v} -> {Utils.pascalize(k), v} end)
      |> Map.new()
    end
  end

  defp get_browser_specific_headers(browser, input_sample) do
    browser_name = String.downcase(browser.name)
    os = input_sample["*OPERATING_SYSTEM"]
    is_mobile = input_sample["*DEVICE"] == "mobile"
    is_http2 = HttpBrowserObject.is_http2(browser)

    platform_versions = %{
      "windows" => ["10.0", "11.0", "6.1", "6.3", "10.0.19045"],
      "macos" => ["10_15_7", "13_2_1", "14_1_1", "14_2_1", "13_5", "12_6"],
      "linux" => ["x86_64", "aarch64", "armv8l", "armv7l"],
      "android" => ["13", "14", "12", "11", "10"],
      "ios" => ["17_1_2", "16_5", "15_7_8", "14_8", "13_7"]
    }

    platform_version = Enum.random(Map.get(platform_versions, os, ["10.0"]))

    base_headers = %{
      "Accept-Encoding" => Enum.random([
        "gzip, deflate, br",
        "gzip, deflate, br, zstd",
        "br, gzip, deflate",
        "gzip, deflate"
      ])
    }

    case browser_name do
      "chrome" ->
        Map.merge(base_headers, get_chrome_headers(browser.version, os, platform_version, is_mobile, is_http2))

      "firefox" ->
        Map.merge(base_headers, get_firefox_headers(browser.version, os, platform_version, is_mobile, is_http2))

      "safari" ->
        Map.merge(base_headers, get_safari_headers(browser.version, os, platform_version, is_mobile, is_http2))

      "edge" ->
        Map.merge(base_headers, get_edge_headers(browser.version, os, platform_version, is_mobile, is_http2))

      _ ->
        base_headers
    end
  end

  defp get_chrome_headers(version, os, platform_version, is_mobile, is_http2) do
    version_str = elem(version, 0)
    platform = normalize_platform(os)
    headers = %{
      "accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
      "sec-ch-ua" => "\"Chromium\";v=\"#{version_str}\", \"Google Chrome\";v=\"#{version_str}\", \"Not?A_Brand\";v=\"99\"",
      "sec-ch-ua-mobile" => if(is_mobile, do: "?1", else: "?0"),
      "sec-ch-ua-platform" => "\"#{platform}\"",
      "sec-ch-ua-platform-version" => "\"#{platform_version}\"",
      "upgrade-insecure-requests" => "1"
    }

    if compare_versions({76, 0, 0, 0}, version) <= 0 do
      Map.merge(headers, get_sec_fetch_headers(is_http2))
    else
      headers
    end
  end

  defp normalize_platform(os) do
    case String.downcase(os) do
      "macos" -> "macOS"
      "ios" -> "iOS"
      "windows" -> "Windows"
      "linux" -> "Linux"
      "android" -> "Android"
      _ -> os
    end
  end

  defp get_firefox_headers(version, os, platform_version, is_mobile, is_http2) do
    headers = %{
      "accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/png,image/svg+xml,*/*;q=0.8",
      "sec-ch-ua-mobile" => if(is_mobile, do: "?1", else: "?0"),
      "sec-ch-ua-platform" => "\"#{normalize_platform(os)}\"",
      "sec-ch-ua-platform-version" => "\"#{platform_version}\"",
      "te" => "trailers",
      "upgrade-insecure-requests" => "1"
    }

    if compare_versions({90, 0, 0}, version) <= 0 do
      Map.merge(headers, get_sec_fetch_headers(is_http2))
    else
      headers
    end
  end

  defp get_safari_headers(_version, os, platform_version, is_mobile, _is_http2) do
    %{
      "accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "accept-encoding" => "gzip, deflate, br",
      "accept-language" => "en-US",
      "upgrade-insecure-requests" => "1",
      "user-agent" => case is_mobile do
        true -> "Mozilla/5.0 (iPhone; CPU iPhone OS #{String.replace(platform_version, "_", "_")} like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        false -> "Mozilla/5.0 (#{if os == "macos", do: "Macintosh", else: os}; Intel Mac OS X #{platform_version}) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15"
      end
    }
  end

  defp get_edge_headers(version, os, platform_version, is_mobile, is_http2) do
    version_str = elem(version, 0)
    headers = %{
      "accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
      "sec-ch-ua" => "\"Microsoft Edge\";v=\"#{version_str}\", \"Not:A-Brand\";v=\"8\", \"Chromium\";v=\"#{version_str}\"",
      "sec-ch-ua-mobile" => if(is_mobile, do: "?1", else: "?0"),
      "sec-ch-ua-platform" => "\"#{normalize_platform(os)}\"",
      "sec-ch-ua-platform-version" => "\"#{platform_version}\"",
      "upgrade-insecure-requests" => "1"
    }

    if compare_versions({79, 0, 0, 0}, version) <= 0 do
      Map.merge(headers, get_sec_fetch_headers(is_http2))
    else
      headers
    end
  end

  defp get_sec_fetch_headers(is_http2) do
    if is_http2 do
      @http2_sec_fetch_attributes
    else
      @http1_sec_fetch_attributes
    end
  end

  # Private functions

  defp prepare_browsers_config(browsers, http_version) do
    browsers
    |> List.wrap()
    |> Enum.map(fn
      %Browser{} = browser ->
        if is_nil(browser.http_version),
          do: %{browser | http_version: http_version},
          else: browser

      name when is_binary(name) ->
        %Browser{name: name, http_version: http_version}
    end)
  end

  defp prepare_http_browser_object(browser_string) do
    case String.split(browser_string, "|") do
      [browser_part, http_version] when browser_part != @missing_value_dataset_token ->
        [browser_name, version_string] = String.split(browser_part, "/")

        version =
          version_string
          |> String.split(".")
          |> Enum.map(&String.to_integer/1)
          |> List.to_tuple()

        %HttpBrowserObject{
          name: browser_name,
          version: version,
          complete_string: browser_string,
          http_version: http_version
        }

      _ ->
        %HttpBrowserObject{
          name: nil,
          version: {},
          complete_string: @missing_value_dataset_token,
          http_version: ""
        }
    end
  end

  defp update_http_version(current_options, options) do
    http_version = Map.get(options, :http_version, current_options.http_version)

    browsers =
      if Map.has_key?(options, :browsers) do
        prepare_browsers_config(options.browsers, http_version)
      else
        # Create a copy of the current browsers with an updated http_version
        Enum.map(current_options.browsers, fn browser ->
          %Browser{
            name: browser.name,
            min_version: browser.min_version,
            max_version: browser.max_version,
            http_version: http_version
          }
        end)
      end

    Map.merge(current_options, options)
    |> Map.put(:browsers, browsers)
    |> Map.put(:http_version, http_version)
  end

  defp get_possible_attribute_values(options) do
    browsers =
      prepare_browsers_config(
        Map.get(options, :browsers, []),
        Map.get(options, :http_version, "2")
      )

    browser_http_options = get_browser_http_options(browsers)

    # Randomly select a subset of browsers and operating systems to increase variety
    selected_browsers = Enum.take_random(browser_http_options, min(5, length(browser_http_options)))
    selected_os = Enum.take_random(
      Map.get(options, :operating_systems, @supported_operating_systems),
      min(2, length(@supported_operating_systems))
    )
    selected_devices = Map.get(options, :devices, @supported_devices)

    %{
      "*BROWSER_HTTP" => selected_browsers,
      "*OPERATING_SYSTEM" => selected_os,
      "*DEVICE" => selected_devices
    }
  end

  defp get_browser_http_options(browsers) do
    # Group unique browsers by name for faster lookup
    browser_map = Enum.group_by(@unique_browsers, & &1.name)

    options =
      browsers
      |> Enum.flat_map(fn browser ->
        available_versions = Map.get(browser_map, browser.name, [])
        |> Enum.filter(fn browser_option ->
          browser.name == browser_option.name and
            (is_nil(browser.min_version) or
               compare_versions(browser.min_version, browser_option.version) <= 0) and
            (is_nil(browser.max_version) or
               compare_versions(browser.max_version, browser_option.version) >= 0) and
            (is_nil(browser.http_version) or
               browser.http_version == browser_option.http_version)
        end)

        # Take a random subset of versions for each browser
        available_versions
        |> Enum.take_random(min(3, length(available_versions)))
        |> Enum.map(& &1.complete_string)
      end)
      |> Enum.shuffle()  # Shuffle to increase randomness

    options
  end

  defp compare_versions(nil, _), do: 0
  defp compare_versions(_, nil), do: 0

  defp compare_versions(version1, version2) when is_binary(version1) do
    v1_parts = version1 |> String.split(".") |> Enum.map(&String.to_integer/1)
    compare_versions(List.to_tuple(v1_parts), version2)
  end

  defp compare_versions(version1, version2) when is_tuple(version1) and is_tuple(version2) do
    v1_list = Tuple.to_list(version1)
    v2_list = Tuple.to_list(version2)

    case {v1_list, v2_list} do
      {[], []} -> 0
      {[], [h2|_]} -> if h2 == 0, do: 0, else: -1
      {[h1|_], []} -> if h1 == 0, do: 0, else: 1
      {[h1|t1], [h2|t2]} ->
        cond do
          h1 > h2 -> 1
          h1 < h2 -> -1
          true -> compare_versions(List.to_tuple(t1), List.to_tuple(t2))
        end
    end
  end

  defp prepare_constraints(possible_attribute_values, http1_values, http2_values) do
    possible_attribute_values
    |> Enum.map(fn {key, values} ->
      filtered_values =
        Enum.filter(values, fn value ->
          filter_value(value, key, http1_values, http2_values)
        end)
      {key, filtered_values}
    end)
    |> Map.new()
  end

  defp filter_value(value, "*BROWSER_HTTP", http1_values, http2_values) do
    case String.split(value, "|") do
      [browser_string, http_version] ->
        # If no user agent constraints, allow all browsers
        if http1_values == %{} and http2_values == %{} do
          true
        else
          case http_version do
            "1" ->
              Map.get(http1_values, "*BROWSER", []) == [] or
                browser_string in Map.get(http1_values, "*BROWSER", [])

            "2" ->
              Map.get(http2_values, "*BROWSER", []) == [] or
                browser_string in Map.get(http2_values, "*BROWSER", [])

            _ ->
              false
          end
        end

      _ ->
        false
    end
  end

  defp filter_value(value, key, http1_values, http2_values) do
    (http1_values == %{} and http2_values == %{}) or
      value in Map.get(http1_values, key, []) or
      value in Map.get(http2_values, key, [])
  end

  defp get_accept_language_header(locales) do
    locales
    |> Enum.with_index()
    |> Enum.map(fn {locale, index} ->
      q_value = Float.round(1.0 - index * 0.1, 1)
      if q_value == 1.0, do: locale, else: "#{locale};q=#{q_value}"
    end)
    |> Enum.join(", ")
  end

  defp pascalize_headers(headers) do
    Utils.pascalize_headers(headers)
  end

  defp order_headers(headers, headers_order) do
    # Get the browser name from User-Agent
    user_agent = Utils.get_user_agent(headers)
    browser_name = Utils.get_browser(user_agent)

    # Get the order for this browser
    order = Map.get(headers_order, browser_name, [])

    # First, add headers in the specified order
    ordered =
      order
      |> Enum.filter(&Map.has_key?(headers, &1))
      |> Enum.map(&{&1, Map.get(headers, &1)})
      |> Map.new()

    # Then add any remaining headers in alphabetical order
    remaining =
      headers
      |> Map.drop(Map.keys(ordered))
      |> Enum.sort_by(fn {key, _} -> key end)
      |> Map.new()

    Map.merge(ordered, remaining)
  end
end
