defmodule BrowserForge.BayesianNetworkTest do
  use ExUnit.Case, async: true

  alias BrowserForge.BayesianNetwork

  @sample_network_definition %{
    "nodes" => [
      %{
        "name" => "parent",
        "possibleValues" => ["X", "Y"],
        "conditionalProbabilities" => %{
          "X" => 0.6,
          "Y" => 0.4
        }
      },
      %{
        "name" => "child",
        "parentNames" => ["parent"],
        "possibleValues" => ["A", "B", "C"],
        "conditionalProbabilities" => %{
          "deeper" => %{
            "X" => %{"A" => 0.6, "B" => 0.3, "C" => 0.1},
            "Y" => %{"A" => 0.2, "B" => 0.3, "C" => 0.5}
          }
        }
      }
    ]
  }

  describe "new/1" do
    test "creates a new BayesianNetwork from a JSON file" do
      path = "test/fixtures/test_network.json"
      File.write!(path, Jason.encode!(@sample_network_definition))
      network = BayesianNetwork.new(path)
      assert length(network.nodes_in_sampling_order) == 2
      assert map_size(network.nodes_by_name) == 2
      File.rm!(path)
    end

    test "creates a new BayesianNetwork from a ZIP file" do
      network = BayesianNetwork.new("test/fixtures/test_network.zip")
      assert length(network.nodes_in_sampling_order) == 2
      assert map_size(network.nodes_by_name) == 2
    end

    test "returns empty network for invalid file" do
      network = BayesianNetwork.new("invalid.txt")
      assert network.nodes_in_sampling_order == []
      assert network.nodes_by_name == %{}
    end
  end

  describe "generate_sample/2" do
    setup do
      path = "test/fixtures/test_network.json"
      File.write!(path, Jason.encode!(@sample_network_definition))
      network = BayesianNetwork.new(path)
      on_exit(fn -> File.rm!(path) end)
      %{network: network}
    end

    test "generates a sample with no input values", %{network: network} do
      sample = BayesianNetwork.generate_sample(network)
      assert Map.has_key?(sample, "parent")
      assert Map.has_key?(sample, "child")
      assert sample["parent"] in ["X", "Y"]
      assert sample["child"] in ["A", "B", "C"]
    end

    test "generates a sample with input values", %{network: network} do
      sample = BayesianNetwork.generate_sample(network, %{"parent" => "X"})
      assert sample["parent"] == "X"
      assert sample["child"] in ["A", "B", "C"]
    end
  end

  describe "generate_consistent_sample_when_possible/2" do
    setup do
      path = "test/fixtures/test_network.json"
      File.write!(path, Jason.encode!(@sample_network_definition))
      network = BayesianNetwork.new(path)
      on_exit(fn -> File.rm!(path) end)
      %{network: network}
    end

    test "generates a consistent sample with valid constraints", %{network: network} do
      sample = BayesianNetwork.generate_consistent_sample_when_possible(network, %{
        "parent" => ["X"],
        "child" => ["A", "B"]
      })
      assert sample["parent"] == "X"
      assert sample["child"] in ["A", "B"]
    end

    test "returns nil for impossible constraints", %{network: network} do
      sample = BayesianNetwork.generate_consistent_sample_when_possible(network, %{
        "parent" => ["Z"],
        "child" => ["D"]
      })
      assert sample == nil
    end
  end

  describe "get_possible_values/2" do
    setup do
      path = "test/fixtures/test_network.json"
      File.write!(path, Jason.encode!(@sample_network_definition))
      network = BayesianNetwork.new(path)
      on_exit(fn -> File.rm!(path) end)
      %{network: network}
    end

    test "returns possible values with valid constraints", %{network: network} do
      values = BayesianNetwork.get_possible_values(network, %{
        "parent" => ["X"],
        "child" => ["A", "B"]
      })
      assert values["parent"] == ["X"]
      assert values["child"] == ["A", "B"]
    end

    test "raises error for empty value list", %{network: network} do
      assert_raise RuntimeError, fn ->
        BayesianNetwork.get_possible_values(network, %{"parent" => []})
      end
    end

    test "raises error for impossible constraints", %{network: network} do
      assert_raise RuntimeError, fn ->
        BayesianNetwork.get_possible_values(network, %{
          "parent" => ["X"],
          "child" => ["D"]
        })
      end
    end

    test "handles non-list values", %{network: network} do
      values = BayesianNetwork.get_possible_values(network, %{
        "parent" => "X",
        "child" => ["A", "B"]
      })
      assert values["child"] == ["A", "B"]
    end
  end
end
