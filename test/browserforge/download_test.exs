defmodule BrowserForge.DownloadTest do
  use ExUnit.Case, async: false
  doctest BrowserForge.Download

  alias BrowserForge.Download

  @temp_dir "test/temp"

  setup do
    # Create temp directory for tests
    File.mkdir_p!(@temp_dir)
    on_exit(fn -> File.rm_rf!(@temp_dir) end)
    :ok
  end

  describe "download/1" do
    test "downloads header files when headers option is true" do
      result = Download.download(headers: true)
      assert result == :ok
      assert Download.downloaded?(headers: true)
    end

    test "downloads fingerprint files when fingerprints option is true" do
      result = Download.download(fingerprints: true)
      assert result == :ok
      assert Download.downloaded?(fingerprints: true)
    end

    test "downloads both types when both options are true" do
      result = Download.download(headers: true, fingerprints: true)
      assert result == :ok
      assert Download.downloaded?(headers: true, fingerprints: true)
    end
  end

  describe "download_if_not_exists/1" do
    test "downloads files when they don't exist" do
      Download.remove()
      refute Download.downloaded?(headers: true)

      result = Download.download_if_not_exists(headers: true)
      assert result == :ok
      assert Download.downloaded?(headers: true)
    end

    test "doesn't download files when they exist" do
      Download.download(headers: true)
      assert Download.downloaded?(headers: true)

      result = Download.download_if_not_exists(headers: true)
      assert result == :ok
    end
  end

  describe "downloaded?/1" do
    test "returns false when files don't exist" do
      Download.remove()
      refute Download.downloaded?(headers: true)
      refute Download.downloaded?(fingerprints: true)
    end

    test "returns true when files exist" do
      Download.download(headers: true, fingerprints: true)
      assert Download.downloaded?(headers: true)
      assert Download.downloaded?(fingerprints: true)
    end
  end

  describe "remove/0" do
    test "removes all downloaded files" do
      Download.download(headers: true, fingerprints: true)
      assert Download.downloaded?(headers: true, fingerprints: true)

      Download.remove()
      refute Download.downloaded?(headers: true, fingerprints: true)
    end
  end
end
