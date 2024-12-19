defmodule BrowserForge.Headers.Browser do
  @moduledoc """
  Represents a browser specification with name, min/max version, and HTTP version.
  """

  @type t :: %__MODULE__{
    name: String.t(),
    min_version: integer() | nil,
    max_version: integer() | nil,
    http_version: String.t()
  }

  defstruct [:name, :min_version, :max_version, http_version: "2"]

  @doc """
  Creates a new Browser struct with the given options.

  ## Options
    * `:name` - The browser name (required)
    * `:min_version` - Minimum browser version (optional)
    * `:max_version` - Maximum browser version (optional)
    * `:http_version` - HTTP version to use, defaults to "2" (optional)

  ## Examples
      iex> Browser.new("chrome")
      %Browser{name: "chrome", http_version: "2"}

      iex> Browser.new("firefox", min_version: 100, max_version: 110)
      %Browser{name: "firefox", min_version: 100, max_version: 110, http_version: "2"}
  """
  def new(name, opts \\ []) when is_binary(name) do
    min_version = Keyword.get(opts, :min_version)
    max_version = Keyword.get(opts, :max_version)
    http_version = to_string(Keyword.get(opts, :http_version, "2"))

    if min_version && max_version && min_version > max_version do
      raise ArgumentError, "min_version (#{min_version}) cannot be greater than max_version (#{max_version})"
    end

    %__MODULE__{
      name: name,
      min_version: min_version,
      max_version: max_version,
      http_version: http_version
    }
  end
end
