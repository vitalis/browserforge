defmodule BrowserForge.Download do
  @moduledoc """
  Downloads and manages the required model definitions for browser fingerprinting.
  """

  require Logger

  @root_dir if Mix.env() == :test,
              do: Path.expand("test/temp"),
              else: :code.priv_dir(:browserforge)

  @data_dirs %{
    headers: Path.join(@root_dir, "headers/data"),
    fingerprints: Path.join(@root_dir, "fingerprints/data")
  }

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

  def download(opts) do
    Enum.each(@data_files, fn {type, files} ->
      if Keyword.get(opts, type, false) do
        Enum.each(files, fn {local_name, remote_name} ->
          url = "#{@remote_paths[type]}/#{remote_name}"
          path = Path.join(@data_dirs[type], local_name)

          case download_file({url, path}) do
            :ok -> Logger.info("#{local_name} downloaded successfully")
            {:error, reason} -> Logger.error("Error downloading #{url} to #{path}: #{reason}")
          end
        end)
      end
    end)
  end

  defp download_file({url, path}) do
    try do
      path |> Path.dirname() |> File.mkdir_p!()

      req_options = Application.get_env(:browserforge, :req_options, [])
      req_options = Keyword.merge([finch: BrowserForge.Finch], req_options)

      case Req.get!(url, req_options) do
        %{status: 200} = response ->
          content =
            cond do
              String.ends_with?(path, ".zip") ->
                # For ZIP files, get the raw binary content
                case response.body do
                  [{_filename, content}] -> content
                  content when is_binary(content) -> content
                end

              is_binary(response.body) ->
                response.body

              true ->
                Jason.encode!(response.body)
            end

          File.write!(path, content)
          :ok

        response ->
          {:error, "Failed to download #{url}: status #{response.status}"}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  def download_if_not_exists(opts) do
    if not is_downloaded(opts) do
      download(opts)
    else
      :ok
    end
  end

  def is_downloaded(opts) do
    Enum.all?(@data_files, fn {type, files} ->
      if Keyword.get(opts, type, false) do
        Enum.all?(files, fn {local_name, _} ->
          path = Path.join(@data_dirs[type], local_name)
          File.exists?(path) and not file_older_than_a_week?(path)
        end)
      else
        true
      end
    end)
  end

  defp file_older_than_a_week?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mtime: mtime}} when is_tuple(mtime) ->
        # Convert Erlang datetime tuple to Unix timestamp
        unix_time =
          :calendar.datetime_to_gregorian_seconds(mtime) -
            :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})

        one_week_ago =
          DateTime.utc_now() |> DateTime.add(-7 * 24 * 60 * 60, :second) |> DateTime.to_unix()

        unix_time < one_week_ago

      _ ->
        true
    end
  end

  def remove_files do
    Enum.each(@data_dirs, fn {_type, dir} ->
      File.rm_rf!(dir)
    end)

    :ok
  end
end
