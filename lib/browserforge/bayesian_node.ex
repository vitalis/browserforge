defmodule BrowserForge.BayesianNode do
  @moduledoc """
  Implementation of a single node in a bayesian network allowing sampling from its conditional distribution.
  """

  defstruct [:node_definition]

  @type t :: %__MODULE__{
    node_definition: map()
  }

  def new(node_definition) do
    %__MODULE__{node_definition: node_definition}
  end

  @doc """
  Extracts unconditional probabilities of node values given the values of the parent nodes.
  """
  def get_probabilities_given_known_values(node, parent_values) do
    probabilities = node.node_definition["conditionalProbabilities"]

    Enum.reduce(parent_names(node), probabilities, fn parent_name, acc ->
      parent_value = Map.get(parent_values, parent_name)

      cond do
        is_map_key(get_in(acc, ["deeper"]) || %{}, parent_value) ->
          get_in(acc, ["deeper", parent_value]) || %{}
        true ->
          get_in(acc, ["skip"]) || %{}
      end
    end)
  end

  @doc """
  Randomly samples from the given values using the given probabilities.
  """
  def sample_random_value_from_possibilities(possible_values, probabilities) do
    anchor = :rand.uniform()
    cumulative_probability = 0.0

    Enum.reduce_while(possible_values, nil, fn possible_value, _acc ->
      new_prob = cumulative_probability + Map.get(probabilities, possible_value, 0.0)
      if new_prob > anchor do
        {:halt, possible_value}
      else
        {:cont, nil}
      end
    end) || List.first(possible_values)
  end

  @doc """
  Randomly samples from the conditional distribution of this node given values of parents.
  """
  def sample(node, parent_values) do
    probabilities = get_probabilities_given_known_values(node, parent_values)
    sample_random_value_from_possibilities(Map.keys(probabilities), probabilities)
  end

  @doc """
  Randomly samples from the conditional distribution of this node given restrictions on the possible values and the values of the parents.
  """
  def sample_according_to_restrictions(node, parent_values, value_possibilities, banned_values) do
    probabilities = get_probabilities_given_known_values(node, parent_values)

    valid_values = Enum.filter(value_possibilities, fn value ->
      value not in banned_values and Map.has_key?(probabilities, value)
    end)

    if valid_values != [] do
      sample_random_value_from_possibilities(valid_values, probabilities)
    else
      nil
    end
  end

  @doc """
  Gets the name of the node.
  """
  def name(node), do: node.node_definition["name"]

  @doc """
  Gets the parent names of the node.
  """
  def parent_names(node), do: node.node_definition["parentNames"] || []

  @doc """
  Gets the possible values of the node.
  """
  def possible_values(node), do: node.node_definition["possibleValues"] || []
end
