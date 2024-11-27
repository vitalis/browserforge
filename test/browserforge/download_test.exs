defmodule BrowserForge.DownloadTest do
  use ExUnit.Case, async: false

  alias BrowserForge.Download

  @temp_dir "test/temp"
  @headers_dir "test/temp/headers/data"
  @fingerprints_dir "test/temp/fingerprints/data"

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

    test_responses = %{
      "browser-helper-file.json" => %{test: "data"},
      "headers-order.json" => %{test: "data"},
      "header-network-definition.zip" => <<80, 75, 5, 6, 0, 0>>,
      "input-network-definition.zip" => <<80, 75, 5, 6, 0, 0>>,
      "fingerprint-network-definition.zip" => <<80, 75, 5, 6, 0, 0>>
    }

    Req.Test.stub(:browserforge, fn _conn ->
      %Req.Response{
        status: 200,
        headers: %{"content-type" => ["application/json"]},
        body: Jason.encode!(%{test: "data"})
      }
    end)

    Application.put_env(:browserforge, :req_options, plug: {Req.Test, :browserforge})

    on_exit(fn ->
      File.rm_rf!(@temp_dir)
      Application.delete_env(:browserforge, :req_options)
    end)

    :ok
  end

  describe "download/1" do
    test "downloads files successfully when valid flags are provided" do
      assert :ok = Download.download(headers: true)
      assert File.exists?(Path.join(@headers_dir, "browser-helper-file.json"))
    end

    test "skips download when files exist and are recent" do
      file_path = Path.join(@headers_dir, "browser-helper-file.json")
      File.write!(file_path, Jason.encode!(%{test: "data"}))

      now = DateTime.utc_now() |> DateTime.to_unix()
      File.touch!(file_path, now)

      assert :ok = Download.download_if_not_exists(headers: true)
    end
  end

  describe "is_downloaded/1" do
    test "returns true when files exist and are recent" do
      Enum.each(@data_files.headers, fn {local_name, _} ->
        file_path = Path.join(@headers_dir, local_name)
        File.write!(file_path, Jason.encode!(%{test: "data"}))

        now = DateTime.utc_now() |> DateTime.to_unix()
        File.touch!(file_path, now)
      end)

      assert Download.is_downloaded(headers: true)
    end

    test "returns false when files don't exist" do
      refute Download.is_downloaded(headers: true)
    end

    test "returns false when files are older than a week" do
      Enum.each(@data_files.headers, fn {local_name, _} ->
        file_path = Path.join(@headers_dir, local_name)
        File.write!(file_path, Jason.encode!(%{test: "data"}))

        old_time =
          DateTime.utc_now() |> DateTime.add(-8 * 24 * 60 * 60, :second) |> DateTime.to_unix()

        File.touch!(file_path, old_time)
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
