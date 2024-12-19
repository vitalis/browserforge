defmodule BrowserForge.BayesianNodeTest do
  use ExUnit.Case, async: true

  alias BrowserForge.BayesianNode

  @sample_node_definition %{
    "name" => "test_node",
    "parentNames" => ["parent1", "parent2"],
    "possibleValues" => ["A", "B", "C"],
    "conditionalProbabilities" => %{
      "deeper" => %{
        "value1" => %{
          "deeper" => %{
            "value2" => %{"A" => 0.6, "B" => 0.3, "C" => 0.1}
          }
        }
      },
      "skip" => %{"A" => 0.5, "B" => 0.3, "C" => 0.2}
    }
  }

  describe "new/1" do
    test "creates a new BayesianNode with the given definition" do
      node = BayesianNode.new(@sample_node_definition)
      assert node.node_definition == @sample_node_definition
    end
  end

  describe "get_probabilities_given_known_values/2" do
    test "returns probabilities from deeper structure when parent values match" do
      node = BayesianNode.new(@sample_node_definition)
      probabilities = BayesianNode.get_probabilities_given_known_values(node, %{
        "parent1" => "value1",
        "parent2" => "value2"
      })
      assert probabilities == %{"A" => 0.6, "B" => 0.3, "C" => 0.1}
    end

    test "returns skip probabilities when parent values don't match" do
      node = BayesianNode.new(@sample_node_definition)
      probabilities = BayesianNode.get_probabilities_given_known_values(node, %{
        "parent1" => "unknown",
        "parent2" => "unknown"
      })
      assert probabilities == %{"A" => 0.5, "B" => 0.3, "C" => 0.2}
    end

    test "returns empty map for invalid conditional probabilities" do
      node = BayesianNode.new(%{
        "name" => "test",
        "parentNames" => ["parent"],
        "possibleValues" => ["A", "B"],
        "conditionalProbabilities" => nil
      })
      assert BayesianNode.get_probabilities_given_known_values(node, %{}) == %{}
    end
  end

  describe "sample_random_value_from_possibilities/2" do
    test "returns a value from the possibilities based on probabilities" do
      possibilities = ["A", "B", "C"]
      probabilities = %{"A" => 0.6, "B" => 0.3, "C" => 0.1}

      result = BayesianNode.sample_random_value_from_possibilities(possibilities, probabilities)
      assert result in possibilities
    end

    test "returns first value when probabilities sum to zero" do
      possibilities = ["A", "B", "C"]
      probabilities = %{"A" => 0.0, "B" => 0.0, "C" => 0.0}

      result = BayesianNode.sample_random_value_from_possibilities(possibilities, probabilities)
      assert result == "A"
    end
  end

  describe "sample/2" do
    test "samples a value based on parent values" do
      node = BayesianNode.new(@sample_node_definition)
      result = BayesianNode.sample(node, %{
        "parent1" => "value1",
        "parent2" => "value2"
      })
      assert result in ["A", "B", "C"]
    end
  end

  describe "sample_according_to_restrictions/4" do
    test "returns a valid value respecting restrictions" do
      node = BayesianNode.new(@sample_node_definition)
      result = BayesianNode.sample_according_to_restrictions(
        node,
        %{"parent1" => "value1", "parent2" => "value2"},
        ["A", "B"],
        ["B"]
      )
      assert result == "A"
    end

    test "returns nil when no valid values are available" do
      node = BayesianNode.new(@sample_node_definition)
      result = BayesianNode.sample_according_to_restrictions(
        node,
        %{"parent1" => "value1", "parent2" => "value2"},
        ["A"],
        ["A"]
      )
      assert result == nil
    end
  end

  describe "name/1" do
    test "returns the node name" do
      node = BayesianNode.new(@sample_node_definition)
      assert BayesianNode.name(node) == "test_node"
    end
  end

  describe "parent_names/1" do
    test "returns the parent names" do
      node = BayesianNode.new(@sample_node_definition)
      assert BayesianNode.parent_names(node) == ["parent1", "parent2"]
    end

    test "returns empty list when no parent names" do
      node = BayesianNode.new(%{"name" => "test"})
      assert BayesianNode.parent_names(node) == []
    end
  end

  describe "possible_values/1" do
    test "returns the possible values" do
      node = BayesianNode.new(@sample_node_definition)
      assert BayesianNode.possible_values(node) == ["A", "B", "C"]
    end

    test "returns empty list when no possible values" do
      node = BayesianNode.new(%{"name" => "test"})
      assert BayesianNode.possible_values(node) == []
    end
  end
end
