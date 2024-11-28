defmodule BrowserForge.HeadersTest do
  use ExUnit.Case
  import Mox

  # Allow any process to set expectations
  setup :set_mox_from_context
  # Verify that all expectations are met after each test
  setup :verify_on_exit!

  setup do
    # Set the mock module for this test
    Application.put_env(:browserforge, :download_module, BrowserForge.MockDownload)
    on_exit(fn -> Application.delete_env(:browserforge, :download_module) end)
    :ok
  end

  describe "setup/0" do
    test "returns :ok when download succeeds" do
      BrowserForge.MockDownload
      |> expect(:download_if_not_exists, fn [headers: true] -> :ok end)

      assert :ok = BrowserForge.Headers.setup()
    end

    test "returns error when download fails" do
      BrowserForge.MockDownload
      |> expect(:download_if_not_exists, fn [headers: true] -> {:error, "download failed"} end)

      assert {:error, "download failed"} = BrowserForge.Headers.setup()
    end
  end
end
