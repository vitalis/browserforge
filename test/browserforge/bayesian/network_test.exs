defmodule BrowserForge.Bayesian.NetworkTest do
  use ExUnit.Case, async: true

  alias BrowserForge.Bayesian.Network

  setup do
    # Create a simple test network definition
    definition = %{
      "nodes" => [
        %{
          "name" => "userAgent",
          "parentNames" => [],
          "possibleValues" => [
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0.4472.124",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/91.0.4472.124"
          ],
          "conditionalProbabilities" => %{
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0.4472.124" => 0.6,
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/91.0.4472.124" => 0.4
          }
        }
      ]
    }

    # Write the definition to a temporary file
    tmp_dir = System.tmp_dir!()
    path = Path.join(tmp_dir, "test-network.json")
    File.write!(path, Jason.encode!(definition))

    # Start the network for each test
    {:ok, pid} = Network.start_link(path)

    on_exit(fn ->
      File.rm(path)
      # Cleanup the process if it's still running
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    {:ok, path: path}
  end

  describe "sample/1" do
    test "generates valid samples" do
      result = Network.sample()

      assert is_map(result)

      assert result["userAgent"] in [
               "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0.4472.124",
               "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/91.0.4472.124"
             ]
    end
  end

  describe "sample_with_restrictions/2" do
    test "generates valid samples with restrictions" do
      restrictions = %{
        "userAgent" => ["Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0.4472.124"]
      }

      assert {:ok, result} = Network.sample_with_restrictions(restrictions)

      assert result["userAgent"] ==
               "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0.4472.124"
    end

    test "handles invalid restrictions" do
      restrictions = %{
        "userAgent" => ["invalid-user-agent"]
      }

      assert {:error, _reason} = Network.sample_with_restrictions(restrictions)
    end
  end
end
