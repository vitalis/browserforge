defmodule BrowserForge.Download do
  @moduledoc """
  Downloads the required model definitions
  """

  require Logger

  defp data_dirs do
    Application.fetch_env!(:browserforge, :data_dirs)
    |> Enum.map(fn {key, path} -> {Atom.to_string(key), path} end)
    |> Map.new()
  end

  @data_files %{
    "headers" => %{
      "browser-helper-file.json" => "browser-helper-file.json",
      "header-network.zip" => "header-network-definition.zip",
      "headers-order.json" => "headers-order.json",
      "input-network.zip" => "input-network-definition.zip"
    },
    "fingerprints" => %{
      "fingerprint-network.zip" => "fingerprint-network-definition.zip"
    }
  }

  @remote_paths %{
    "headers" => "https://github.com/apify/fingerprint-suite/raw/refs/tags/v2.1.58/packages/header-generator/src/data_files",
    "fingerprints" => "https://github.com/apify/fingerprint-suite/raw/refs/tags/v2.1.58/packages/fingerprint-generator/src/data_files"
  }

  @doc """
  Downloads the required data files based on the provided options.
  """
  @spec download(keyword()) :: :ok | {:error, term()}
  def download(opts \\ []) do
    Logger.info("Downloading model definition files...")

    enabled_flags = get_enabled_flags(opts)

    try do
      enabled_flags
      |> Enum.flat_map(&download_files_for_type/1)
      |> Enum.all?(&match?({:ok, _}, &1))
      |> case do
        true -> :ok
        false -> {:error, :download_failed}
      end
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Downloads files if they don't exist.
  """
  @spec download_if_not_exists(keyword()) :: :ok | {:error, term()}
  def download_if_not_exists(opts \\ []) do
    case downloaded?(opts) do
      true -> :ok
      false -> download(opts)
    end
  end

  @doc """
  Checks if the required data files are already downloaded.
  """
  @spec downloaded?(keyword()) :: boolean()
  def downloaded?(opts \\ []) do
    opts
    |> get_all_paths()
    |> Enum.all?(&File.exists?/1)
  end

  @doc """
  Removes all downloaded data files.
  """
  @spec remove() :: :ok
  def remove do
    [headers: true, fingerprints: true]
    |> get_all_paths()
    |> Enum.each(&File.rm/1)

    :ok
  end

  # Private functions

  defp get_enabled_flags(flags) do
    flags
    |> Enum.filter(fn {_key, value} -> value end)
    |> Enum.map(fn {key, _} -> Atom.to_string(key) end)
  end

  defp get_all_paths(flags) do
    flags
    |> get_enabled_flags()
    |> Enum.flat_map(fn data_type ->
      data_path = data_dirs()[data_type]

      @data_files[data_type]
      |> Map.keys()
      |> Enum.map(&Path.join(data_path, &1))
    end)
  end

  defp download_files_for_type(data_type) do
    @data_files[data_type]
    |> Enum.map(fn {local_name, remote_name} ->
      url = "#{@remote_paths[data_type]}/#{remote_name}"
      path = Path.join(data_dirs()[data_type], local_name)

      case download_file(url, path) do
        :ok ->
          Logger.info("#{String.pad_trailing(local_name, 30)}OK!")
          {:ok, path}
        {:error, reason} = error ->
          Logger.error("Error downloading #{local_name}: #{inspect(reason)}")
          error
      end
    end)
  end

  defp download_file(url, path, redirect_count \\ 0) do
    path |> Path.dirname() |> File.mkdir_p!()

    if redirect_count > 5 do
      {:error, "Too many redirects"}
    else
      request = Finch.build(:get, url, [
        {"Accept", "*/*"},
        {"User-Agent", "BrowserForge/1.0"}
      ])

      case Finch.request(request, BrowserForge.Finch) do
        {:ok, %Finch.Response{status: status, headers: headers}} when status in [301, 302, 303, 307, 308] ->
          case List.keyfind(headers, "location", 0) do
            {_, location} -> download_file(location, path, redirect_count + 1)
            nil -> {:error, "Redirect without location header"}
          end
        {:ok, %Finch.Response{status: 200, body: body}} ->
          File.write(path, body)
        {:ok, %Finch.Response{status: status}} ->
          {:error, "Download failed with status code: #{status}"}
        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
