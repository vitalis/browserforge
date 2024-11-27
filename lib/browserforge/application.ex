defmodule BrowserForge.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: BrowserForge.Finch}
    ]

    opts = [strategy: :one_for_one, name: BrowserForge.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
