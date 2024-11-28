defmodule Mix.Tasks.Browserforge.UpdateFixtures do
  @moduledoc "Updates test fixtures from the source repository"
  use Mix.Task

  @fixtures_dir "test/fixtures"
  @data_files %{
    headers: %{
      "browser-helper-file.json" => "browser-helper-file.json",
      "header-network.zip" => "header-network-definition.zip",
      "headers-order.json" => "headers-order.json",
      "input-network.zip" => "input-network-definition.zip"
    },
    fingerprints: %{
      "fingerprint-network.zip" => "fingerprint-network-definition.zip"
    }
  }

  @remote_paths %{
    headers:
      "https://github.com/apify/fingerprint-suite/raw/master/packages/header-generator/src/data_files",
    fingerprints:
      "https://github.com/apify/fingerprint-suite/raw/master/packages/fingerprint-generator/src/data_files"
  }

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Enum.each(@data_files, fn {category, files} ->
      fixtures_category_dir = Path.join(@fixtures_dir, Atom.to_string(category))
      File.mkdir_p!(fixtures_category_dir)

      remote_base_url = Map.fetch!(@remote_paths, category)

      Enum.each(files, fn {local_name, remote_name} ->
        target_path = Path.join(fixtures_category_dir, local_name)
        download_file(remote_base_url, remote_name, target_path)
      end)
    end)
  end

  defp download_file(base_url, filename, target_path) do
    url = "#{base_url}/#{filename}"

    case :httpc.request(:get, {String.to_charlist(url), []}, [], body_format: :binary) do
      {:ok, {{_, 200, _}, _, body}} ->
        File.write!(target_path, body)
        Mix.shell().info("Downloaded #{Path.basename(target_path)}")

      {:ok, {{_, status, _}, _, body}} ->
        Mix.raise("Failed to download #{filename}: HTTP #{status}\n#{body}")

      {:error, reason} ->
        Mix.raise("Failed to download #{filename}: #{inspect(reason)}")
    end
  end
end
