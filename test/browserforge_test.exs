defmodule BrowserForgeTest do
  use ExUnit.Case
  doctest BrowserForge

  test "greets the world" do
    assert BrowserForge.hello() == :world
  end
end
