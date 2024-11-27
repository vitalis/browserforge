defmodule BrowserForge.Bayesian.Node do
  @moduledoc """
  Implementation of a single node in a Bayesian network allowing sampling from its conditional distribution.
  """

  @type t :: %__MODULE__{
    name: String.t(),
    parent_names: [String.t()],
    possible_values: [String.t()],
    node_definition: map()
  }

  defstruct [:name, :parent_names, :possible_values, :node_definition]

  @doc """
  Creates a new Bayesian node from a node definition.
  """
  @spec new(map()) :: t()
  def new(node_definition) do
    %__MODULE__{
      name: node_definition["name"],
      parent_names: node_definition["parentNames"] || [],
      possible_values: node_definition["possibleValues"] || [],
      node_definition: node_definition
    }
  end

  @doc """
  Extracts unconditional probabilities of node values given the values of the parent nodes.
  """
  @spec get_probabilities_given_known_values(t(), map()) :: map()
  def get_probabilities_given_known_values(%__MODULE__{} = node, parent_values) do
    probabilities = get_in(node.node_definition, ["conditionalProbabilities"])

    Enum.reduce(node.parent_names, probabilities, fn parent_name, probs ->
      parent_value = Map.get(parent_values, parent_name)

      case get_in(probs, ["deeper", parent_value]) do
        nil -> Map.get(probs, "skip", %{})
        deeper_probs -> deeper_probs
      end
    end)
  end

  @doc """
  Randomly samples from the given values using the given probabilities.
  """
  @spec sample_random_value_from_possibilities([String.t()], map()) :: String.t()
  def sample_random_value_from_possibilities(possible_values, probabilities) do
    anchor = :rand.uniform()

    {value, _} = Enum.reduce_while(possible_values, {nil, 0.0}, fn value, {_, cumulative} ->
      new_cumulative = cumulative + Map.get(probabilities, value, 0.0)

      if new_cumulative > anchor do
        {:halt, {value, new_cumulative}}
      else
        {:cont, {value, new_cumulative}}
      end
    end)

    value || List.first(possible_values)
  end

  @doc """
  Randomly samples from the conditional distribution of this node given values of parents.
  """
  @spec sample(t(), map()) :: String.t()
  def sample(%__MODULE__{} = node, parent_values) do
    probabilities = get_probabilities_given_known_values(node, parent_values)
    sample_random_value_from_possibilities(Map.keys(probabilities), probabilities)
  end

  @doc """
  Randomly samples from the conditional distribution of this node given restrictions
  on the possible values and the values of the parents.
  """
  @spec sample_according_to_restrictions(t(), map(), Enumerable.t(), [String.t()]) :: String.t() | nil
  def sample_according_to_restrictions(%__MODULE__{} = node, parent_values, value_possibilities, banned_values) do
    probabilities = get_probabilities_given_known_values(node, parent_values)

    valid_values =
      value_possibilities
      |> Enum.filter(fn value ->
        value not in banned_values and Map.has_key?(probabilities, value)
      end)

    case valid_values do
      [] -> nil
      values -> sample_random_value_from_possibilities(values, probabilities)
    end
  end
end
