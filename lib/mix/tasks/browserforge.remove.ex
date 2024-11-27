defmodule Mix.Tasks.Browserforge.Remove do
  @moduledoc """
  Removes all downloaded fingerprint definition files.

  ## Examples

      $ mix browserforge.remove
  """

  use Mix.Task
  alias BrowserForge.Download

  @shortdoc "Removes all downloaded fingerprint files"

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started(:browserforge)
    Download.remove_files()
    Mix.shell().info([:yellow, "Removed all files!"])
  end
end
