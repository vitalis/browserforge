defmodule Mix.Tasks.Browserforge.DownloadTestData do
  use Mix.Task

  @shortdoc "Downloads test data files"
  @switches [force: :boolean]

  def run(args) do
    {opts, _} = OptionParser.parse!(args, switches: @switches)
    force = Keyword.get(opts, :force, false)

    # Override data directories for test data
    Application.put_env(:browserforge, :data_dirs, %{
      headers: Path.join(["test", "fixtures", "headers", "data"]),
      fingerprints: Path.join(["test", "fixtures", "fingerprints", "data"])
    })

    # Start required applications
    Application.ensure_all_started(:browserforge)

    # Ensure directories exist
    data_dirs = Application.fetch_env!(:browserforge, :data_dirs)
    Enum.each(data_dirs, fn {_key, path} ->
      path
      |> Path.expand()
      |> File.mkdir_p!()
    end)

    # Download files
    if force do
      BrowserForge.Download.remove()
    end

    case BrowserForge.Download.download(headers: true) do
      :ok -> Mix.shell().info("Test data files downloaded successfully")
      {:error, reason} -> Mix.raise("Failed to download test data: #{inspect(reason)}")
    end
  end
end
