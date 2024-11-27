defmodule BrowserForge.MixProject do
  use Mix.Project

  def project do
    [
      app: :browserforge,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :telemetry],
      mod: {BrowserForge.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.4.0"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.15"},
      {:finch, "~> 0.10"}
    ]
  end
end
