import Config

config :browserforge,
  data_dirs: %{
    headers: Path.join(["test", "fixtures", "headers", "data"]),
    fingerprints: Path.join(["test", "fixtures", "fingerprints", "data"])
  }
