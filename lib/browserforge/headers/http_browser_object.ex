defmodule BrowserForge.Headers.HttpBrowserObject do
  @moduledoc """
  Represents a browser object with HTTP version information.
  """

  defstruct [:name, :version, :complete_string, :http_version]

  @doc """
  Returns true if the browser object is using HTTP/2, false otherwise.
  """
  def is_http2(%__MODULE__{http_version: http_version}) do
    http_version == "2"
  end
end
