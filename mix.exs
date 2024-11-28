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
      {:typed_struct, "~> 0.3.0"},
      {:req, "~> 0.4.0"},
      {:jason, "~> 1.4"},
      # Dev/Test deps
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18.0", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:plug, "~> 1.14", only: :test}
    ]
  end
end
