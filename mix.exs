defmodule BrowserForge.MixProject do
  use Mix.Project

  def project do
    [
      app: :browserforge,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex.pm specific fields
      description: "Intelligent browser header & fingerprint generator for Elixir",
      package: package(),

      # Docs
      name: "BrowserForge",
      source_url: "https://github.com/vitalis/browserforge",
      homepage_url: "https://github.com/vitalis/browserforge",
      docs: [
        main: "BrowserForge",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl],
      mod: {BrowserForge.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:finch, "~> 0.19"},

      # Dev and test dependencies
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      name: "browserforge",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/vitalis/browserforge"
      },
      maintainers: ["Vitaly Gorodetsky"]
    ]
  end
end
