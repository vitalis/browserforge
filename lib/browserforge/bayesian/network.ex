defmodule BrowserForge.Bayesian.Network do
  @moduledoc """
  Implementation of a Bayesian network capable of randomly sampling from its distribution.
  Maintains state as a GenServer.
  """

  use GenServer
  require Logger

  alias BrowserForge.Bayesian.Node
  alias BrowserForge.Bayesian.Utils

  @type network_options :: [
          name: atom()
        ]

  @doc """
  Starts the Bayesian network server.
  """
  def start_link(path, opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, path, name: name)
  end

  @doc """
  Samples random values for all nodes in the network.
  """
  def sample(server \\ __MODULE__) do
    GenServer.call(server, :sample)
  end

  @doc """
  Samples random values for all nodes in the network with given restrictions.
  """
  def sample_with_restrictions(restrictions, server \\ __MODULE__) do
    GenServer.call(server, {:sample_with_restrictions, restrictions})
  end

  # Server callbacks

  @impl true
  def init(path) do
    case Utils.extract_json(path) do
      {:ok, network_definition} ->
        nodes = Enum.map(network_definition["nodes"], &Node.new/1)
        nodes_by_name = Map.new(nodes, &{&1.name, &1})

        {:ok,
         %{
           nodes_in_sampling_order: nodes,
           nodes_by_name: nodes_by_name
         }}

      {:error, reason} ->
        Logger.error("Failed to initialize Bayesian network: #{reason}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:sample, _from, state) do
    result = do_sample(state.nodes_in_sampling_order, %{})
    {:reply, result, state}
  end

  @impl true
  def handle_call({:sample_with_restrictions, restrictions}, _from, state) do
    case Utils.get_possible_values(state, restrictions) do
      {:ok, extended_restrictions} ->
        case do_sample_with_restrictions(
               state.nodes_in_sampling_order,
               extended_restrictions,
               %{}
             ) do
          {:error, reason} -> {:reply, {:error, reason}, state}
          result -> {:reply, {:ok, result}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private functions

  defp do_sample(nodes, sampled_values) do
    Enum.reduce(nodes, sampled_values, fn node, values ->
      Map.put(values, node.name, Node.sample(node, values))
    end)
  end

  defp do_sample_with_restrictions(nodes, restrictions, sampled_values) do
    Enum.reduce_while(nodes, sampled_values, fn node, values ->
      case sample_node_with_restrictions(node, values, restrictions) do
        nil -> {:halt, {:error, "Failed to sample valid value for #{node.name}"}}
        value -> {:cont, Map.put(values, node.name, value)}
      end
    end)
  end

  defp sample_node_with_restrictions(node, values, restrictions) do
    case Map.get(restrictions, node.name) do
      nil ->
        Node.sample(node, values)

      possible_values ->
        Node.sample_according_to_restrictions(
          node,
          values,
          possible_values,
          []
        )
    end
  end
end
