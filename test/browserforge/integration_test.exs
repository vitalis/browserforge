defmodule BrowserForge.IntegrationTest do
  use ExUnit.Case, async: false

  alias BrowserForge.{Download, Bayesian.Network}

  @moduletag :integration

  setup do
    # Ensure we're using test directory
    Application.put_env(:browserforge, :root_dir, Path.expand("test/temp"))

    # Clean any existing files
    Download.remove_files()

    on_exit(fn ->
      Download.remove_files()
    end)

    :ok
  end

  describe "headers generation integration" do
    test "downloads header files and verifies their existence" do
      # First ensure files don't exist
      refute Download.is_downloaded(headers: true)

      # Download the header files
      assert :ok = Download.download(headers: true)
      assert Download.is_downloaded(headers: true)

      # Verify specific header files exist
      headers_dir = Path.join([Application.get_env(:browserforge, :root_dir), "headers/data"])

      assert File.exists?(Path.join(headers_dir, "browser-helper-file.json"))
      assert File.exists?(Path.join(headers_dir, "header-network.zip"))
      assert File.exists?(Path.join(headers_dir, "headers-order.json"))
      assert File.exists?(Path.join(headers_dir, "input-network.zip"))

      # Verify files are readable and contain valid data
      browser_helper = Path.join(headers_dir, "browser-helper-file.json") |> File.read!()
      assert {:ok, _json} = Jason.decode(browser_helper)
    end
  end

  describe "fingerprint generation integration" do
    test "downloads network definition and generates valid fingerprints" do
      # First ensure files don't exist
      refute Download.is_downloaded(fingerprints: true)

      # Download the network definition
      assert :ok = Download.download(fingerprints: true)
      assert Download.is_downloaded(fingerprints: true)

      # Start the Bayesian Network with downloaded definition
      definition_path =
        Path.join([
          Application.get_env(:browserforge, :root_dir),
          "fingerprints/data/fingerprint-network.zip"
        ])

      assert {:ok, _pid} = Network.start_link(definition_path)

      # Test unrestricted sampling
      sample = Network.sample()
      assert is_map(sample)
      assert Map.keys(sample) |> length() > 0

      # Test sampling with restrictions
      restrictions = %{
        "userAgent" => [
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
        ]
      }

      assert {:ok, restricted_sample} = Network.sample_with_restrictions(restrictions)

      # Verify restrictions are met
      assert restricted_sample["userAgent"] in restrictions["userAgent"]

      # Test invalid restrictions
      invalid_restrictions = %{
        "platform" => ["InvalidPlatform"],
        "browserName" => ["InvalidBrowser"]
      }

      assert {:error, _reason} = Network.sample_with_restrictions(invalid_restrictions)

      # Test multiple samples for consistency
      samples = for _i <- 1..10, do: Network.sample()

      # Verify all samples have the same structure
      [first_sample | rest] = samples
      first_keys = Map.keys(first_sample) |> Enum.sort()

      for sample <- rest do
        assert Map.keys(sample) |> Enum.sort() == first_keys
      end

      # Verify samples are different (not just returning the same values)
      unique_samples = Enum.uniq(samples)
      assert length(unique_samples) > 1
    end
  end
end
