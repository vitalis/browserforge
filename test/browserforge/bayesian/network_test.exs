defmodule BrowserForge.Bayesian.NetworkTest do
  use ExUnit.Case, async: true

  alias BrowserForge.Bayesian.Network

  @network_definition %{
    "nodes" => [
      %{
        "name" => "os",
        "parentNames" => [],
        "possibleValues" => ["windows", "macos", "linux"],
        "conditionalProbabilities" => %{
          "windows" => 0.6,
          "macos" => 0.3,
          "linux" => 0.1
        }
      },
      %{
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
            },
            "linux" => %{
              "chrome" => 0.5,
              "firefox" => 0.4,
              "safari" => 0.1
            }
          }
        }
      }
    ]
  }

  setup do
    test_path = Path.join(System.tmp_dir!(), "test_network.json")
    File.write!(test_path, Jason.encode!(@network_definition))

    start_supervised!({Network, test_path})

    on_exit(fn ->
      File.rm!(test_path)
    end)

    %{path: test_path}
  end

  describe "sample/1" do
    test "generates valid samples" do
      :rand.seed(:exsss, {1, 2, 3})

      result = Network.sample()

      assert is_map(result)
      assert result["os"] in ["windows", "macos", "linux"]
      assert result["browser"] in ["chrome", "firefox", "safari"]
    end
  end

  describe "sample_with_restrictions/2" do
    test "generates valid samples with restrictions" do
      :rand.seed(:exsss, {1, 2, 3})

      restrictions = %{
        "os" => ["windows"],
        "browser" => ["chrome", "firefox"]
      }

      assert {:ok, result} = Network.sample_with_restrictions(restrictions)
      assert result["os"] == "windows"
      assert result["browser"] in ["chrome", "firefox"]
    end
  end
end
