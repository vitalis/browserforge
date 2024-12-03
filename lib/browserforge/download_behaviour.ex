defmodule BrowserForge.DownloadBehaviour do
  @callback download_if_not_exists(keyword()) :: :ok | {:error, String.t()}
end
