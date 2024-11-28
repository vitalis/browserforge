defmodule BrowserForge.Headers do
  @moduledoc """
  Entry point for header generation functionality.
  """

  @doc """
  Sets up the headers module by downloading required files.
  Returns :ok on success or {:error, reason} on failure.
  """
  @spec setup() :: :ok | {:error, String.t()}
  def setup do
    download_module = Application.get_env(:browserforge, :download_module, BrowserForge.Download)

    case download_module.download_if_not_exists(headers: true) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
