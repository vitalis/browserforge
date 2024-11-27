defmodule BrowserForge.Bayesian.UtilsTest do
  use ExUnit.Case, async: true
  alias BrowserForge.Bayesian.{Utils, Node}

  describe "undeeper/1" do
    test "flattens nested deeper structures" do
      input = %{
        "deeper" => %{
          "a" => %{
            "deeper" => %{
              "b" => %{"x" => 1}
            }
          }
        }
      }

      expected = %{
        "a" => %{
          "b" => %{"x" => 1}
        }
      }

      assert Utils.undeeper(input) == expected
    end
  end

  describe "array_zip/2" do
    test "combines arrays by concatenating elements" do
      arr1 = [{1}, {2}]
      arr2 = [{3}, {4}]
      expected = [{1, 3}, {2, 4}]

      assert Utils.array_zip(arr1, arr2) == expected
    end
  end

  describe "array_intersection/2" do
    test "returns intersection of two arrays" do
      arr1 = [1, 2, 3]
      arr2 = [2, 3, 4]
      expected = [2, 3]

      assert Utils.array_intersection(arr1, arr2) |> Enum.sort() == expected
    end
  end

  describe "filter_by_last_level_keys/2" do
    test "returns paths to specified keys" do
      tree = %{
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

      result = Utils.filter_by_last_level_keys(tree, ["chrome", "firefox"])
      assert length(result) > 0
      assert {"windows", "chrome"} in result
      assert {"windows", "firefox"} in result
      assert {"macos", "chrome"} in result
      assert {"macos", "firefox"} in result
    end
  end

  describe "get_possible_values/2" do
    test "computes possible values given restrictions" do
      # Create a test network state with proper Node structs
      node =
        Node.new(%{
          "name" => "browser",
          "parentNames" => ["os"],
          "possibleValues" => ["chrome", "firefox"],
          "conditionalProbabilities" => %{
            "deeper" => %{
              "windows" => %{
                "chrome" => 0.6,
                "firefox" => 0.4
              }
            }
          }
        })

      network_state = %{
        nodes: [node],
        nodes_by_name: %{"browser" => node}
      }

      restrictions = %{
        "browser" => ["chrome", "firefox"]
      }

      assert {:ok, result} = Utils.get_possible_values(network_state, restrictions)
      assert result["browser"] == ["chrome", "firefox"]
    end
  end

  describe "extract_json/1" do
    setup do
      tmp_dir = System.tmp_dir!()
      json_path = Path.join(tmp_dir, "test.json")
      zip_path = Path.join(tmp_dir, "test.zip")
      fake_zip_path = Path.join(tmp_dir, "fake.zip")

      json_content = Jason.encode!(%{"test" => "data"})

      # Regular JSON file
      File.write!(json_path, json_content)

      # Real ZIP file containing JSON
      {:ok, {~c"test.zip", zip_binary}} =
        :zip.create(~c"test.zip", [{~c"test.json", json_content}], [:memory])

      File.write!(zip_path, zip_binary)

      # JSON file with .zip extension (as in our real use case)
      File.write!(fake_zip_path, json_content)

      on_exit(fn ->
        File.rm(json_path)
        File.rm(zip_path)
        File.rm(fake_zip_path)
      end)

      %{
        json_path: json_path,
        zip_path: zip_path,
        fake_zip_path: fake_zip_path
      }
    end

    test "extracts JSON from regular file", %{json_path: path} do
      assert {:ok, %{"test" => "data"}} = Utils.extract_json(path)
    end

    test "extracts JSON from real ZIP file", %{zip_path: path} do
      assert {:ok, %{"test" => "data"}} = Utils.extract_json(path)
    end

    test "extracts JSON from fake ZIP file (JSON with .zip extension)", %{fake_zip_path: path} do
      assert {:ok, %{"test" => "data"}} = Utils.extract_json(path)
    end

    test "handles missing file" do
      assert {:error, _} = Utils.extract_json("nonexistent.json")
    end
  end
end
