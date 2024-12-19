defmodule BrowserForge.Test.Setup do
  @moduledoc """
  Test setup helpers
  """

  def ensure_test_dirs do
    data_dirs = Application.fetch_env!(:browserforge, :data_dirs)

    Enum.each(data_dirs, fn {_key, path} ->
      path
      |> Path.join(Application.app_dir(:browserforge))
      |> File.mkdir_p!()
    end)
  end
end
