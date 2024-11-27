defmodule BrowserForge.DownloadTest do
  use ExUnit.Case, async: false

  alias BrowserForge.Download

  @temp_dir "test/temp"
  @headers_dir "test/temp/headers/data"
  @fingerprints_dir "test/temp/fingerprints/data"

  @zip_content <<80, 75, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

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

  setup do
    File.rm_rf!(@temp_dir)
    File.mkdir_p!(@headers_dir)
    File.mkdir_p!(@fingerprints_dir)

    Application.put_env(:browserforge, :req_options,
      plug: fn conn ->
        cond do
          String.ends_with?(conn.request_path, ".json") ->
            Plug.Conn.resp(conn, 200, Jason.encode!(%{test: "data"}))

          String.ends_with?(conn.request_path, ".zip") ->
            Plug.Conn.resp(conn, 200, @zip_content)
        end
      end
    )

    on_exit(fn ->
      File.rm_rf!(@temp_dir)
      Application.delete_env(:browserforge, :req_options)
    end)

    :ok
  end

  describe "download/1" do
    test "downloads files successfully when valid flags are provided" do
      assert :ok = Download.download(headers: true)

      Enum.each(@data_files.headers, fn {local_name, _} ->
        assert File.exists?(Path.join(@headers_dir, local_name))
      end)
    end

    test "skips download when files exist and are recent" do
      Enum.each(@data_files.headers, fn {local_name, _} ->
        file_path = Path.join(@headers_dir, local_name)

        content =
          if String.ends_with?(local_name, ".json"),
            do: Jason.encode!(%{test: "data"}),
            else: @zip_content

        File.write!(file_path, content)
      end)

      assert :ok = Download.download_if_not_exists(headers: true)
    end
  end

  describe "is_downloaded/1" do
    test "returns true when files exist and are recent" do
      Enum.each(@data_files.headers, fn {local_name, _} ->
        file_path = Path.join(@headers_dir, local_name)

        content =
          if String.ends_with?(local_name, ".json"),
            do: Jason.encode!(%{test: "data"}),
            else: @zip_content

        File.write!(file_path, content)
      end)

      assert Download.is_downloaded(headers: true)
    end

    test "returns false when files don't exist" do
      refute Download.is_downloaded(headers: true)
    end

    test "returns false when files are older than a week" do
      Enum.each(@data_files.headers, fn {local_name, _} ->
        file_path = Path.join(@headers_dir, local_name)

        content =
          if String.ends_with?(local_name, ".json"),
            do: Jason.encode!(%{test: "data"}),
            else: @zip_content

        File.write!(file_path, content)

        old_time = :calendar.universal_time() |> :calendar.datetime_to_gregorian_seconds()
        old_time = old_time - 8 * 24 * 60 * 60
        old_datetime = :calendar.gregorian_seconds_to_datetime(old_time)
        File.touch!(file_path, old_datetime)
      end)

      refute Download.is_downloaded(headers: true)
    end
  end

  describe "remove_files/0" do
    test "removes all downloaded files" do
      file_path = Path.join(@headers_dir, "browser-helper-file.json")
      File.write!(file_path, Jason.encode!(%{test: "data"}))

      assert :ok = Download.remove_files()
      refute File.exists?(file_path)
    end
  end
end
