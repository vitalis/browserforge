defmodule BrowserForge.Bayesian.Utils do
  @moduledoc """
  Helper functions for Bayesian network operations.
  Provides functionality for JSON extraction, probability tree manipulation,
  and value filtering/intersection operations.
  """

  alias BrowserForge.Bayesian.Node

  @type path :: Path.t()
  @type json_result :: {:ok, map()} | {:error, String.t()}
  @type probability_tree :: %{String.t() => probability_tree | number()}
  @type value_set :: MapSet.t(String.t())

  @doc """
  Extracts JSON from a file, handling both regular JSON files and ZIP files containing JSON.
  Matches Python's extract_json functionality with improved error handling.
  """
  @spec extract_json(path()) :: json_result()
  def extract_json(path) do
    with {:ok, content} <- File.read(path) do
      case Path.extname(path) do
        ".zip" -> handle_zip_content(path, content)
        _ -> Jason.decode(content)
      end
    else
      {:error, reason} -> {:error, "Failed to read file: #{inspect(reason)}"}
    end
  rescue
    e -> {:error, "Unexpected error: #{Exception.message(e)}"}
  end

  @doc """
  Flattens nested "deeper" structures in conditional probabilities.
  Matches Python's implementation for handling conditional probability trees.
  """
  @spec undeeper(probability_tree()) :: probability_tree()
  def undeeper(%{"deeper" => deeper}) when is_map(deeper) do
    deeper
    |> Enum.map(fn {key, value} -> {key, undeeper(value)} end)
    |> Map.new()
  end

  def undeeper(tree) when is_map(tree), do: tree

  @doc """
  Combines two arrays by concatenating their elements pairwise.
  Matches Python's array_zip functionality.
  """
  @spec array_zip([tuple()], [tuple()]) :: [tuple()]
  def array_zip(arr1, arr2) do
    Enum.zip_with(arr1, arr2, fn t1, t2 -> Tuple.append(t1, elem(t2, 0)) end)
  end

  @doc """
  Returns the intersection of two arrays.
  Matches Python's array_intersection with improved type handling.
  """
  @spec array_intersection(Enumerable.t(), Enumerable.t()) :: [any()]
  def array_intersection(arr1, arr2) do
    arr1
    |> List.wrap()
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(List.wrap(arr2)))
    |> MapSet.to_list()
  end

  @doc """
  Filters tree by last level keys and returns paths to those keys.
  Matches Python's filter_by_last_level_keys with improved pattern matching.
  """
  @spec filter_by_last_level_keys(probability_tree(), [String.t()]) :: [tuple() | String.t()]
  def filter_by_last_level_keys(%{"deeper" => deeper}, valid_keys) when is_map(deeper) do
    deeper
    |> Enum.flat_map(fn {parent_key, child_map} ->
      child_map
      |> Enum.filter(fn {key, _value} -> key in valid_keys end)
      |> Enum.map(fn {key, _value} -> {parent_key, key} end)
    end)
  end

  def filter_by_last_level_keys(tree, valid_keys) when is_map(tree) do
    tree
    |> Enum.filter(fn {key, _value} -> key in valid_keys end)
    |> Enum.map(fn {key, _value} -> key end)
  end

  def filter_by_last_level_keys(_, _), do: []

  @doc """
  Gets possible values for nodes given restrictions.
  Matches Python's get_possible_values with improved error handling.
  """
  @spec get_possible_values(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def get_possible_values(network_state, restrictions) do
    with {:ok, sets} <- compute_node_sets(network_state, restrictions),
         {:ok, result} <- compute_value_intersections(sets) do
      {:ok, result}
    end
  end

  # Private Functions

  defp handle_zip_content(path, content) do
    case Jason.decode(content) do
      {:ok, json} ->
        {:ok, json}

      {:error, _} ->
        case :zip.unzip(String.to_charlist(path), [:memory]) do
          {:ok, files} ->
            extract_json_from_zip_files(files)

          {:error, reason} ->
            {:error, "Failed to extract ZIP: #{inspect(reason)}"}
        end
    end
  end

  defp extract_json_from_zip_files(files) do
    files
    |> Enum.find(fn {name, _} -> String.ends_with?(to_string(name), ".json") end)
    |> case do
      {_name, content} -> Jason.decode(content)
      nil -> {:error, "No JSON file found in ZIP"}
    end
  end

  defp compute_node_sets(network_state, restrictions) do
    restrictions
    |> Enum.reduce_while([], fn {key, value}, acc ->
      case compute_node_set(network_state, key, value) do
        {:ok, set} -> {:cont, [set | acc]}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      sets when is_list(sets) -> {:ok, sets}
    end
  end

  @spec compute_node_set(map(), String.t(), [String.t()]) :: {:ok, map()} | {:error, String.t()}
  defp compute_node_set(network_state, key, values) when is_list(values) and values != [] do
    case Map.get(network_state.nodes_by_name, key) do
      %Node{} = node ->
        tree = undeeper(node.node_definition["conditionalProbabilities"])
        paths = filter_by_last_level_keys(tree, values)

        parent_values = Enum.zip(node.parent_names, paths) |> Map.new()
        {:ok, Map.put(parent_values, key, values)}

      nil ->
        {:error, "Node not found: #{key}"}
    end
  end

  defp compute_node_set(_network_state, key, _values) do
    {:error, "Invalid restriction value for #{key}"}
  end

  defp compute_value_intersections(sets) do
    sets
    |> Enum.reduce_while(%{}, fn set, acc ->
      case merge_set_values(set, acc) do
        {:ok, new_acc} -> {:cont, new_acc}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      result when is_map(result) -> {:ok, result}
    end
  end

  defp merge_set_values(set, acc) do
    Enum.reduce_while(set, {:ok, acc}, fn {key, values}, {:ok, inner_acc} ->
      case Map.get(inner_acc, key) do
        nil ->
          {:cont, {:ok, Map.put(inner_acc, key, values)}}

        existing_values ->
          case array_intersection(values, existing_values) do
            [] -> {:halt, {:error, "No possible values found for #{key}"}}
            intersection -> {:cont, {:ok, Map.put(inner_acc, key, intersection)}}
          end
      end
    end)
  end
end
