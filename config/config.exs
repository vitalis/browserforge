import Config

config :browserforge,
  data_dirs: %{
    headers: Path.join(["priv", "headers", "data"]),
    fingerprints: Path.join(["priv", "fingerprints", "data"])
  }

config :browserforge, BrowserForge.Finch,
  timeout: 60_000,
  recv_timeout: 60_000
