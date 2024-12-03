import Config

config :browserforge,
  root_dir: Path.expand("priv")

import_config "#{config_env()}.exs"
