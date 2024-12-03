defmodule BrowserForge.Test.Fixtures do
  @moduledoc """
  Helper module for managing test fixtures
  """

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

  def setup_fixtures(category) when category in [:headers, :fingerprints] do
    data_dir = get_data_dir(category)

    # Ensure the directory exists and is clean
    File.rm_rf!(data_dir)
    File.mkdir_p!(data_dir)

    files = Map.fetch!(@data_files, category)
    fixtures_category_dir = Path.join(@fixtures_dir, Atom.to_string(category))

    # Copy each file and verify it exists
    Enum.each(files, fn {local_name, _} ->
      source = Path.join(fixtures_category_dir, local_name)
      target = Path.join(data_dir, local_name)

      if File.exists?(source) do
        File.cp!(source, target)

        unless File.exists?(target) do
          raise "Failed to copy fixture file: #{local_name}"
        end
      else
        raise "Missing fixture file: #{source}"
      end
    end)

    {:ok, data_dir}
  end

  def cleanup_fixtures(category) when category in [:headers, :fingerprints] do
    data_dir = get_data_dir(category)
    # Only remove files, not the directory itself
    case File.ls(data_dir) do
      {:ok, files} ->
        Enum.each(files, fn file ->
          File.rm!(Path.join(data_dir, file))
        end)

      {:error, _} ->
        :ok
    end
  end

  defp get_data_dir(:headers), do: Application.app_dir(:browserforge, ["priv", "headers", "data"])

  defp get_data_dir(:fingerprints),
    do: Application.app_dir(:browserforge, ["priv", "fingerprints", "data"])
end
