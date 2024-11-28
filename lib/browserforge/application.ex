defmodule BrowserForge.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Start Finch first
    children = [
      {Finch, name: BrowserForge.Finch},
      BrowserForge.Supervisor
    ]

    opts = [strategy: :one_for_one, name: BrowserForge.Application]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # After Finch is started, ensure directories and download files
        priv_dir = Application.get_env(:browserforge, :priv_dir, :code.priv_dir(:browserforge))
        File.mkdir_p!(Path.join(priv_dir, "headers/data"))
        File.mkdir_p!(Path.join(priv_dir, "fingerprints/data"))

        # Download files after Finch is started
        BrowserForge.Download.download_if_not_exists(fingerprints: true)

        # Start Bayesian Network after files are downloaded
        DynamicSupervisor.start_child(
          BrowserForge.NetworkSupervisor,
          {BrowserForge.Bayesian.Network,
           Path.join(priv_dir, "fingerprints/data/fingerprint-network.zip")}
        )

        {:ok, pid}

      error ->
        error
    end
  end
end
