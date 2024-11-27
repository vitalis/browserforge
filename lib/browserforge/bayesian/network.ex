defmodule BrowserForge.Bayesian.Network do
  @moduledoc """
  Implementation of a Bayesian Network for browser fingerprint generation.
  Provides functionality for sampling values based on conditional probabilities
  and handling restrictions on possible values.
  """

  use GenServer
  alias BrowserForge.Bayesian.{Node, Utils}

  @type network_state :: %{
    nodes: [Node.t()],
    nodes_by_name: %{String.t() => Node.t()}
  }
  @type sample_result :: {:ok, map()} | {:error, String.t()}
  @type restrictions :: %{String.t() => [String.t()]}

  # Client API

  @doc """
  Starts the Bayesian Network server with the given network definition file.
  """
  @spec start_link(Path.t()) :: GenServer.on_start()
  def start_link(definition_path) do
    GenServer.start_link(__MODULE__, definition_path, name: __MODULE__)
  end

  @doc """
  Generates a random sample from the network without restrictions.
  """
  @spec sample() :: map()
  def sample do
    GenServer.call(__MODULE__, :sample)
  end

  @doc """
  Generates a random sample from the network with the given restrictions.
  Matches Python's sample_with_restrictions functionality.
  """
  @spec sample_with_restrictions(restrictions()) :: sample_result()
  def sample_with_restrictions(restrictions) do
    GenServer.call(__MODULE__, {:sample_with_restrictions, restrictions})
  end

  # Server Callbacks

  @impl true
  def init(definition_path) do
    case Utils.extract_json(definition_path) do
      {:ok, definition} ->
        nodes = Enum.map(definition["nodes"], &Node.new/1)
        nodes_by_name = Map.new(nodes, &{&1.name, &1})
        {:ok, %{nodes: nodes, nodes_by_name: nodes_by_name}}

      {:error, reason} ->
        {:stop, "Failed to load network definition: #{reason}"}
    end
  end

  @impl true
  def handle_call(:sample, _from, state) do
    result = generate_sample(state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:sample_with_restrictions, restrictions}, _from, state) do
    result = generate_restricted_sample(state, restrictions)
    {:reply, result, state}
  end

  # Private Functions

  @spec generate_sample(network_state()) :: map()
  defp generate_sample(state) do
    state.nodes
    |> Enum.reduce(%{}, fn node, values ->
      parent_values = Map.take(values, node.parent_names)
      Map.put(values, node.name, Node.sample(node, parent_values))
    end)
  end

  @spec generate_restricted_sample(network_state(), restrictions()) :: sample_result()
  defp generate_restricted_sample(state, restrictions) do
    with {:ok, possible_values} <- Utils.get_possible_values(state, restrictions),
         {:ok, sample} <- try_generate_valid_sample(state, possible_values, 100) do
      {:ok, sample}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec try_generate_valid_sample(network_state(), map(), non_neg_integer()) :: sample_result()
  defp try_generate_valid_sample(_state, _possible_values, 0) do
    {:error, "Failed to generate valid sample after maximum attempts"}
  end

  defp try_generate_valid_sample(state, possible_values, attempts_left) do
    sample = generate_sample(state)

    if sample_satisfies_restrictions?(sample, possible_values) do
      {:ok, sample}
    else
      try_generate_valid_sample(state, possible_values, attempts_left - 1)
    end
  end

  @spec sample_satisfies_restrictions?(map(), map()) :: boolean()
  defp sample_satisfies_restrictions?(sample, possible_values) do
    Enum.all?(possible_values, fn {key, allowed_values} ->
      sample[key] in allowed_values
    end)
  end
end
