defmodule BrowserForge.Supervisor do
  @moduledoc """
  Supervisor for BrowserForge components, managing the Bayesian networks
  for fingerprint and header generation.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {DynamicSupervisor, name: BrowserForge.NetworkSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: BrowserForge.TaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Starts a new BayesianNetwork with the given definition path.
  """
  def start_network(definition_path) do
    DynamicSupervisor.start_child(
      BrowserForge.NetworkSupervisor,
      {BrowserForge.Bayesian.Network, definition_path}
    )
  end

  @doc """
  Stops a running BayesianNetwork.
  """
  def stop_network(pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(BrowserForge.NetworkSupervisor, pid)
  end
end
