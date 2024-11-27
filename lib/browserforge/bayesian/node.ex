defmodule BrowserForge.Bayesian.Node do
  @moduledoc """
  Implementation of a single node in a Bayesian network.
  Provides functionality for sampling from conditional probability distributions
  and managing node relationships within the network.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          parent_names: [String.t()],
          possible_values: [String.t()],
          node_definition: map()
        }

  @type parent_values :: %{String.t() => String.t()}
  @type probability_map :: %{String.t() => float()}

  defstruct [:name, :parent_names, :possible_values, :node_definition]

  @doc """
  Creates a new Bayesian node from a node definition.
  """
  @spec new(map()) :: t()
  def new(definition) do
    %__MODULE__{
      name: definition["name"],
      parent_names: definition["parentNames"] || [],
      possible_values: definition["possibleValues"] || [],
      node_definition: definition
    }
  end

  @doc """
  Samples a random value from the node's conditional distribution given parent values.
  """
  @spec sample(t(), parent_values()) :: String.t()
  def sample(node, parent_values) do
    probabilities = get_probabilities_given_known_values(node, parent_values)
    sample_random_value_from_possibilities(node.possible_values, probabilities)
  end

  @doc """
  Gets the conditional probabilities for this node given parent values.
  """
  @spec get_probabilities_given_known_values(t(), parent_values()) :: probability_map()
  def get_probabilities_given_known_values(node, parent_values) do
    probabilities = node.node_definition["conditionalProbabilities"]

    case traverse_probability_tree(probabilities, node.parent_names, parent_values) do
      probs when is_map(probs) -> probs
      _ -> node.node_definition["conditionalProbabilities"]
    end
  end

  @doc """
  Samples a value according to given restrictions.
  Returns nil if no valid values are available.
  """
  @spec sample_according_to_restrictions(t(), parent_values(), [String.t()], [String.t()]) ::
          String.t() | nil
  def sample_according_to_restrictions(node, parent_values, allowed_values, excluded_values) do
    probabilities = get_probabilities_given_known_values(node, parent_values)

    valid_values =
      node.possible_values
      |> Enum.filter(&(&1 in allowed_values))
      |> Enum.reject(&(&1 in excluded_values))

    case valid_values do
      [] -> nil
      values -> sample_random_value_from_possibilities(values, probabilities)
    end
  end

  # Private Functions

  @spec sample_random_value_from_possibilities([String.t()], probability_map()) :: String.t()
  defp sample_random_value_from_possibilities(possible_values, probabilities) do
    total_prob = Enum.sum(Map.values(probabilities))

    if total_prob <= 0 do
      Enum.random(possible_values)
    else
      normalized_probs = Map.new(probabilities, fn {k, v} -> {k, v / total_prob} end)
      random = :rand.uniform()

      {_final_cum, value} = Enum.reduce_while(possible_values, {0.0, List.first(possible_values)},
        fn value, {cum, _} ->
          new_cum = cum + Map.get(normalized_probs, value, 0.0)
          if random <= new_cum, do: {:halt, {new_cum, value}}, else: {:cont, {new_cum, value}}
        end)

      value
    end
  end

  defp traverse_probability_tree(tree, [], _parent_values), do: tree

  defp traverse_probability_tree(%{"deeper" => deeper}, [parent_name | rest], parent_values) do
    case Map.get(parent_values, parent_name) do
      nil -> %{}
      value ->
        case Map.get(deeper, value) do
          nil -> %{}
          subtree -> traverse_probability_tree(subtree, rest, parent_values)
        end
    end
  end

  defp traverse_probability_tree(probabilities, _parent_names, _parent_values) when is_map(probabilities), do: probabilities
  defp traverse_probability_tree(_invalid, _parent_names, _parent_values), do: %{}
end
