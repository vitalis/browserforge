defmodule BrowserForge.BayesianNetwork do
  @moduledoc """
  Implementation of a bayesian network capable of randomly sampling from its distribution.
  """

  alias BrowserForge.BayesianNode

  defstruct [:nodes_in_sampling_order, :nodes_by_name]

  @type t :: %__MODULE__{
    nodes_in_sampling_order: [BayesianNode.t()],
    nodes_by_name: %{String.t() => BayesianNode.t()}
  }

  def new(path) do
    network_definition = read_network_file(path)
    nodes = network_definition
    |> Map.get("nodes", [])
    |> Enum.map(&BayesianNode.new/1)

    %__MODULE__{
      nodes_in_sampling_order: nodes,
      nodes_by_name: Map.new(nodes, &{BayesianNode.name(&1), &1})
    }
  end

  @doc """
  Randomly samples from the distribution represented by the bayesian network.
  """
  def generate_sample(network, input_values \\ %{}) do
    Enum.reduce(network.nodes_in_sampling_order, input_values, fn node, sample ->
      if not Map.has_key?(sample, BayesianNode.name(node)) do
        Map.put(sample, BayesianNode.name(node), BayesianNode.sample(node, sample))
      else
        sample
      end
    end)
  end

  @doc """
  Randomly samples values from the distribution represented by the bayesian network,
  making sure the sample is consistent with the provided restrictions on value possibilities.
  Returns nil if no such sample can be generated.
  """
  def generate_consistent_sample_when_possible(network, value_possibilities) do
    try do
      recursively_generate_consistent_sample_when_possible(network, %{}, value_possibilities, 0)
    rescue
      _ -> nil
    end
  end

  @doc """
  Given a network instance and a set of user constraints, returns an extended
  set of constraints induced by the original constraints and network structure.
  """
  def get_possible_values(network, possible_values) do
    sets = Enum.flat_map(possible_values, fn {key, value} ->
      case value do
        value when is_list(value) or is_tuple(value) ->
          if value == [], do: raise "The current constraints are too restrictive. No possible values can be found for the given constraints."

          node = Map.get(network.nodes_by_name, key)
          tree = undeeper(get_in(node.node_definition, ["conditionalProbabilities"]))
          zipped_values = filter_by_last_level_keys(tree, value)

          [Map.merge(
            Enum.zip(BayesianNode.parent_names(node), zipped_values) |> Map.new(),
            %{key => value}
          )]

        _ -> []
      end
    end)

    # Compute the intersection of all the possible values for each node
    Enum.reduce(sets, %{}, fn set_dict, result ->
      Enum.reduce(set_dict, result, fn {key, values}, acc ->
        case Map.get(acc, key) do
          nil -> Map.put(acc, key, values)
          existing_values ->
            intersected = array_intersection(values, existing_values)
            if intersected == [], do: raise "The current constraints are too restrictive. No possible values can be found for the given constraints."
            Map.put(acc, key, intersected)
        end
      end)
    end)
  end

  # Private functions

  defp recursively_generate_consistent_sample_when_possible(network, sample_so_far, value_possibilities, depth) do
    if depth == length(network.nodes_in_sampling_order) do
      sample_so_far
    else
      node = Enum.at(network.nodes_in_sampling_order, depth)
      do_generate_sample(network, node, sample_so_far, value_possibilities, depth, [])
    end
  end

  defp do_generate_sample(network, node, sample_so_far, value_possibilities, depth, banned_values) do
    possible_values = Map.get(value_possibilities, BayesianNode.name(node), BayesianNode.possible_values(node))

    case BayesianNode.sample_according_to_restrictions(node, sample_so_far, possible_values, banned_values) do
      nil -> nil
      sample_value ->
        sample_so_far = Map.put(sample_so_far, BayesianNode.name(node), sample_value)

        case recursively_generate_consistent_sample_when_possible(network, sample_so_far, value_possibilities, depth + 1) do
          nil ->
            # Try again with this value banned
            do_generate_sample(network, node, Map.delete(sample_so_far, BayesianNode.name(node)),
                           value_possibilities, depth, [sample_value | banned_values])
          next_sample -> next_sample
        end
    end
  end

  defp read_network_file(path) do
    case Path.extname(path) do
      ".json" ->
        path
        |> File.read!()
        |> Jason.decode!()

      ".zip" ->
        with {:ok, zip_files} <- :zip.unzip(String.to_charlist(path), [:memory]),
             {_, content} <- Enum.find(zip_files, fn {name, _} ->
               String.ends_with?(to_string(name), ".json")
             end),
             {:ok, json} <- Jason.decode(content) do
          json
        else
          _ -> %{}
        end

      _ -> %{}
    end
  end

  defp undeeper(obj) when not is_map(obj), do: obj
  defp undeeper(obj) do
    Enum.reduce(obj, %{}, fn
      {"skip", _}, acc -> acc
      {"deeper", value}, acc -> Map.merge(acc, undeeper(value))
      {key, value}, acc -> Map.put(acc, key, undeeper(value))
    end)
  end

  defp filter_by_last_level_keys(tree, valid_keys) do
    {out, _} = filter_by_last_level_keys_recurse(tree, valid_keys, [], [])
    out
  end

  defp filter_by_last_level_keys_recurse(tree, valid_keys, acc, out) when is_map(tree) do
    Enum.reduce(tree, {out, acc}, fn
      {key, value}, {current_out, current_acc} when is_map(value) ->
        filter_by_last_level_keys_recurse(value, valid_keys, [key | current_acc], current_out)
      {key, _}, {current_out, current_acc} ->
        if key in valid_keys do
          new_out = if current_out == [], do: Enum.map(current_acc, &[&1]),
                                        else: array_zip(current_out, Enum.map(current_acc, &[&1]))
          {new_out, current_acc}
        else
          {current_out, current_acc}
        end
    end)
  end

  defp array_intersection(a, b) do
    set_b = MapSet.new(b)
    Enum.filter(a, &MapSet.member?(set_b, &1))
  end

  defp array_zip(a, b) do
    Enum.zip(a, b)
    |> Enum.map(fn {x, y} -> MapSet.new(x) |> MapSet.union(MapSet.new(y)) |> MapSet.to_list() end)
  end
end
