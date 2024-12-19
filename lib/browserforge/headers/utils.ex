defmodule BrowserForge.Headers.Utils do
  @moduledoc """
  Utility functions for header generation.
  """

  @doc """
  Retrieves the User-Agent from the headers dictionary.
  """
  def get_user_agent(headers) do
    Map.get(headers, "User-Agent") || Map.get(headers, "user-agent")
  end

  @doc """
  Determines the browser name from the User-Agent string.
  """
  def get_browser(user_agent) when is_binary(user_agent) do
    cond do
      String.contains?(user_agent, "Firefox") -> "firefox"
      String.contains?(user_agent, "Chrome") -> "chrome"
      String.contains?(user_agent, "Safari") -> "safari"
      String.contains?(user_agent, "Edge") -> "edge"
      true -> nil
    end
  end
  def get_browser(_), do: nil

  @pascalize_upper ~w(dnt rtt ect)

  @doc """
  Converts a header name to Pascal case.
  """
  def pascalize(name) when is_binary(name) do
    cond do
      String.starts_with?(name, ":") or String.starts_with?(name, "sec-ch-ua") ->
        name

      name in @pascalize_upper ->
        String.upcase(name)

      true ->
        name
        |> String.split("-")
        |> Enum.map(&String.capitalize/1)
        |> Enum.join("-")
    end
  end

  @doc """
  Converts all header names in a map to Pascal case.
  """
  def pascalize_headers(headers) do
    headers
    |> Enum.map(fn {key, value} -> {pascalize(key), value} end)
    |> Map.new()
  end

  @doc """
  Converts a value to a tuple if it's not already an enumerable.
  """
  def tuplify(obj) when is_list(obj) or is_tuple(obj) or is_nil(obj), do: obj
  def tuplify(obj), do: {obj}
end
