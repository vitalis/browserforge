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

      value =
        Node.sample_according_to_restrictions(
          node,
          %{"os" => "windows"},
          ["chrome", "firefox"],
          ["safari"]
        )

      assert value in ["chrome", "firefox"]
    end

    test "returns nil when no valid values available" do
      node = Node.new(@sample_node_definition)

      value =
        Node.sample_according_to_restrictions(
          node,
          %{"os" => "windows"},
          ["edge"],
          ["chrome", "firefox", "safari"]
        )

      assert is_nil(value)
    end
  end

  describe "sampling stability" do
    setup do
      node =
        Node.new(%{
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
        })

      {:ok, node: node}
    end

    test "samples respect probability distributions", %{node: node} do
      # Take a large number of samples to verify distribution
      samples_count = 10_000
      windows_samples = for _ <- 1..samples_count, do: Node.sample(node, %{"os" => "windows"})

      # Count occurrences
      windows_dist = Enum.frequencies(windows_samples)

      # Verify proportions are roughly correct (within 5% margin)
      assert_within_margin(windows_dist["chrome"] / samples_count, 0.6, 0.05)
      assert_within_margin(windows_dist["firefox"] / samples_count, 0.3, 0.05)
      assert_within_margin(windows_dist["safari"] / samples_count, 0.1, 0.05)
    end

    test "handles edge case probabilities", %{node: _node} do
      edge_node =
        Node.new(%{
          "name" => "test",
          "possibleValues" => ["a", "b"],
          "conditionalProbabilities" => %{
            "a" => 1.0,
            "b" => 0.0
          }
        })

      # Should always choose "a" given probability 1.0
      samples = for _ <- 1..100, do: Node.sample(edge_node, %{})
      assert Enum.all?(samples, &(&1 == "a"))
    end

    test "handles uniform distribution when probabilities sum to 0", %{node: _node} do
      zero_prob_node =
        Node.new(%{
          "name" => "test",
          "possibleValues" => ["a", "b"],
          "conditionalProbabilities" => %{
            "a" => 0.0,
            "b" => 0.0
          }
        })

      samples = for _ <- 1..1000, do: Node.sample(zero_prob_node, %{})
      frequencies = Enum.frequencies(samples)

      # Both values should appear and be roughly equal
      assert map_size(frequencies) == 2
      assert_within_margin(frequencies["a"] / 1000, 0.5, 0.1)
      assert_within_margin(frequencies["b"] / 1000, 0.5, 0.1)
    end

    test "maintains stability across parent value changes", %{node: node} do
      # Sample with different parent values
      windows_sample = Node.sample(node, %{"os" => "windows"})
      macos_sample = Node.sample(node, %{"os" => "macos"})

      # Multiple samples should always be from possible values
      assert windows_sample in ["chrome", "firefox", "safari"]
      assert macos_sample in ["chrome", "firefox", "safari"]

      # Verify stability with same parent values and seed
      :rand.seed(:exsss, {1, 2, 3})
      first_sample = Node.sample(node, %{"os" => "windows"})
      :rand.seed(:exsss, {1, 2, 3})
      second_sample = Node.sample(node, %{"os" => "windows"})

      assert first_sample == second_sample
    end
  end

  # Helper function to assert value is within margin of expected
  defp assert_within_margin(actual, expected, margin) do
    assert abs(actual - expected) <= margin,
           "Expected #{actual} to be within #{margin} of #{expected}"
  end
end
