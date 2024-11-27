defmodule BrowserForge.Bayesian.NodeTest do
  use ExUnit.Case, async: true
  alias BrowserForge.Bayesian.Node

  @sample_node_definition %{
    "name" => "browser",
    "parentNames" => ["os"],
    "possibleValues" => ["chrome", "firefox", "safari"],
    "conditionalProbabilities" => %{
      "deeper" => %{
        "windows" => %{
          "chrome" => 0.6,
          "firefox" => 0.3,
          "safari" => 0.1
        },
        "macos" => %{
          "chrome" => 0.4,
          "firefox" => 0.2,
          "safari" => 0.4
        }
      }
    }
  }

  describe "new/1" do
    test "creates a new node from definition" do
      node = Node.new(@sample_node_definition)
      assert node.name == "browser"
      assert node.parent_names == ["os"]
      assert node.possible_values == ["chrome", "firefox", "safari"]
    end
  end

  describe "get_probabilities_given_known_values/2" do
    test "returns correct probabilities for given parent values" do
      node = Node.new(@sample_node_definition)
      probabilities = Node.get_probabilities_given_known_values(node, %{"os" => "windows"})

      assert probabilities == %{
        "chrome" => 0.6,
        "firefox" => 0.3,
        "safari" => 0.1
      }
    end

    test "returns skip probabilities when parent value not found" do
      node = Node.new(@sample_node_definition)
      probabilities = Node.get_probabilities_given_known_values(node, %{"os" => "linux"})
      assert probabilities == %{}
    end
  end

  describe "sample/2" do
    test "samples value according to probabilities" do
      node = Node.new(@sample_node_definition)
      :rand.seed(:exsss, {1, 2, 3})

      # With fixed seed, we can predict the outcome
      value = Node.sample(node, %{"os" => "windows"})
      assert value in ["chrome", "firefox", "safari"]
    end
  end

  describe "sample_according_to_restrictions/4" do
    test "samples value according to restrictions" do
      node = Node.new(@sample_node_definition)
      :rand.seed(:exsss, {1, 2, 3})

      value = Node.sample_according_to_restrictions(
        node,
        %{"os" => "windows"},
        ["chrome", "firefox"],
        ["safari"]
      )

      assert value in ["chrome", "firefox"]
    end

    test "returns nil when no valid values available" do
      node = Node.new(@sample_node_definition)

      value = Node.sample_according_to_restrictions(
        node,
        %{"os" => "windows"},
        ["edge"],
        ["chrome", "firefox", "safari"]
      )

      assert is_nil(value)
    end
  end
end
