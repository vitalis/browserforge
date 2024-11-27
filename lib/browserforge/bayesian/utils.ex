defmodule BrowserForge.Bayesian.Utils do
  @moduledoc """
  Helper functions for Bayesian network operations.
  """

  @doc """
  Extracts JSON from a file, handling both regular JSON files and ZIP files containing JSON.
  """
  @spec extract_json(Path.t()) :: {:ok, map()} | {:error, String.t()}
  def extract_json(path) do
    with {:ok, content} <- File.read(path) do
      case Path.extname(path) do
        ".zip" ->
          # First try to parse as JSON (for JSON files with .zip extension)
          case Jason.decode(content) do
            {:ok, json} -> {:ok, json}
            {:error, _} ->
              # If JSON parsing fails, try to handle as actual ZIP
              case :zip.unzip(content, [:memory]) do
                {:ok, [{_name, zip_content} | _]} -> Jason.decode(zip_content)
                {:error, reason} -> {:error, "Failed to extract ZIP: #{inspect(reason)}"}
              end
          end

        _ ->
          Jason.decode(content)
      end
    else
      {:error, reason} -> {:error, "Failed to read file: #{inspect(reason)}"}
    end
  rescue
    e -> {:error, "Unexpected error: #{Exception.message(e)}"}
  end

  @doc """
  Flattens nested "deeper" structures in conditional probabilities.
  """
  @spec undeeper(map()) :: map()
  def undeeper(tree) when is_map(tree) do
    if Map.has_key?(tree, "deeper") do
      tree["deeper"]
      |> Enum.map(fn {key, value} -> {key, undeeper(value)} end)
      |> Map.new()
    else
      tree
    end
  end

  @doc """
  Combines two arrays by concatenating their elements pairwise.
  """
  @spec array_zip([tuple()], [tuple()]) :: [tuple()]
  def array_zip(arr1, arr2) do
    Enum.zip_with(arr1, arr2, fn t1, t2 -> Tuple.append(t1, elem(t2, 0)) end)
  end

  @doc """
  Returns the intersection of two arrays.
  """
  @spec array_intersection(Enumerable.t(), Enumerable.t()) :: [any()]
  def array_intersection(arr1, arr2) when is_list(arr1) and is_list(arr2) do
    set1 = MapSet.new(List.wrap(arr1))
    set2 = MapSet.new(List.wrap(arr2))
    MapSet.intersection(set1, set2) |> MapSet.to_list()
  end

  def array_intersection(value1, value2) do
    array_intersection(List.wrap(value1), List.wrap(value2))
  end

  @doc """
  Filters tree by last level keys and returns paths to those keys.
  """
  @spec filter_by_last_level_keys(map(), [String.t()]) :: [tuple()]
  def filter_by_last_level_keys(tree, valid_keys) do
    case tree do
      %{"deeper" => deeper} ->
        deeper
        |> Enum.flat_map(fn {parent_key, child_map} ->
          child_map
          |> Enum.filter(fn {key, _value} -> key in valid_keys end)
          |> Enum.map(fn {key, _value} -> {parent_key, key} end)
        end)

      tree when is_map(tree) ->
        tree
        |> Enum.filter(fn {key, _value} -> key in valid_keys end)
        |> Enum.map(fn {key, _value} -> key end)

      _ ->
        []
    end
  end

  @doc """
  Gets possible values for nodes given restrictions.
  """
  @spec get_possible_values(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def get_possible_values(network_state, restrictions) do
    with {:ok, sets} <- compute_node_sets(network_state, restrictions),
         {:ok, result} <- compute_value_intersections(sets) do
      {:ok, result}
    end
  end

  defp compute_node_sets(network_state, restrictions) do
    sets =
      Enum.reduce_while(restrictions, [], fn {key, value}, acc ->
        case compute_node_set(network_state, key, value) do
          {:ok, set} -> {:cont, [set | acc]}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case sets do
      {:error, reason} -> {:error, reason}
      sets when is_list(sets) -> {:ok, sets}
    end
  end

  defp compute_node_set(network_state, key, values) when is_list(values) and length(values) > 0 do
    node = network_state.nodes_by_name[key]
    tree = undeeper(node.node_definition["conditionalProbabilities"])
    paths = filter_by_last_level_keys(tree, values)

    # Create a map with parent names and their possible values
    parent_values = Enum.zip(node.parent_names, paths) |> Map.new()
    set = Map.put(parent_values, key, values)

    {:ok, set}
  end

  defp compute_node_set(_network_state, key, _values) do
    {:error, "Invalid restriction value for #{key}"}
  end

  defp compute_value_intersections(sets) do
    result =
      Enum.reduce_while(sets, %{}, fn set, acc ->
        case merge_set_values(set, acc) do
          {:ok, new_acc} -> {:cont, new_acc}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case result do
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
