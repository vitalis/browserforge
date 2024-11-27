defmodule Mix.Tasks.Browserforge.Update do
  @moduledoc """
  Fetches header and fingerprint definitions.

  ## Command line options

    * `--headers` - Only update header definitions
    * `--fingerprints` - Only update fingerprint definitions

  If no options are provided, both headers and fingerprints will be updated.

  ## Examples

      $ mix browserforge.update
      $ mix browserforge.update --headers
      $ mix browserforge.update --fingerprints
  """

  use Mix.Task
  alias BrowserForge.Download

  @shortdoc "Updates browser fingerprint definitions"

  @impl Mix.Task
  def run(args) do
    Application.ensure_all_started(:browserforge)

    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          headers: :boolean,
          fingerprints: :boolean
        ]
      )

    # If no options passed, mark both as true
    opts =
      case {Keyword.get(opts, :headers), Keyword.get(opts, :fingerprints)} do
        {nil, nil} -> [headers: true, fingerprints: true]
        _ -> opts
      end

    case Download.download(opts) do
      :ok ->
        Mix.shell().info([:green, "Successfully updated definitions!"])

      {:error, reason} ->
        Mix.shell().error("Failed to update definitions: #{reason}")
        exit({:shutdown, 1})
    end
  end
end
