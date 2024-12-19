defmodule BrowserForge.Test.SetupFixtures do
  @moduledoc """
  Downloads and prepares test fixtures.
  """

  @fixtures_dir Path.join([File.cwd!(), "test/fixtures"])
  @headers_data_dir Path.join([@fixtures_dir, "headers/data"])

  def setup do
    File.mkdir_p!(@headers_data_dir)
    download_header_files()
  end

  defp download_header_files do
    files = [
      "browser-helper-file.json",
      "headers-order.json",
      "input-network.zip",
      "header-network.zip"
    ]

    base_url = "https://raw.githubusercontent.com/proxy-scraper/browserforge/main/browserforge/headers/data/"

    Enum.each(files, fn file ->
      url = base_url <> file
      local_path = Path.join(@headers_data_dir, file)

      unless File.exists?(local_path) do
        {:ok, %{body: body}} = Finch.build(:get, url) |> Finch.request(BrowserForge.Finch)
        File.write!(local_path, body)
      end
    end)
  end
end

# Run setup when this file is loaded
BrowserForge.Test.SetupFixtures.setup()
