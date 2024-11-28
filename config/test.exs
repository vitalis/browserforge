import Config

config :browserforge,
  download_module: BrowserForge.MockDownload,
  root_dir: Path.expand("test/temp")
