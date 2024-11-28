defmodule BrowserForge.Headers.Utils do
  @moduledoc """
  Utility functions for header generation and manipulation.
  """

  @pascalize_upper ~w(dnt rtt ect)

  @doc """
  Retrieves the User-Agent from the headers dictionary.
  """
  @spec get_user_agent(map()) :: String.t() | nil
  def get_user_agent(headers) do
    headers["User-Agent"] || headers["user-agent"]
  end

  @doc """
  Determines the browser name from the User-Agent string.
  """
  @spec get_browser(String.t()) :: String.t() | nil
  def get_browser(user_agent) do
    cond do
      String.contains?(user_agent, "Firefox") -> "firefox"
      String.contains?(user_agent, "Chrome") -> "chrome"
      String.contains?(user_agent, "Safari") -> "safari"
      String.contains?(user_agent, "Edge") -> "edge"
      true -> nil
    end
  end

  @doc """
  Converts header names to proper case format.
  """
  @spec pascalize(String.t()) :: String.t()
  def pascalize(name) do
    cond do
      String.starts_with?(name, ":") or String.starts_with?(name, "sec-ch-ua") ->
        name
      name in @pascalize_upper ->
        String.upcase(name)
      true ->
        String.capitalize(name)
    end
  end

  @doc """
  Converts all header names in a map to proper case format.
  """
  @spec pascalize_headers(map()) :: map()
  def pascalize_headers(headers) do
    Map.new(headers, fn {key, value} -> {pascalize(key), value} end)
  end

  @doc """
  Converts a value to a tuple if it's not already enumerable.
  """
  @spec tuplify(any()) :: tuple() | nil
  def tuplify(obj) when is_list(obj), do: List.to_tuple(obj)
  def tuplify(obj) when is_tuple(obj), do: obj
  def tuplify(nil), do: nil
  def tuplify(obj), do: {obj}
end 
