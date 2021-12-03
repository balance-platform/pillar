defmodule Pillar.MixProject do
  use Mix.Project

  @source_url "https://github.com/balance-platform/pillar"
  @version "0.25.1"

  def project do
    [
      app: :pillar,
      name: "Pillar",
      aliases: aliases(),
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      description: description(),
      package: package(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_add_deps: :transitive
      ],
      homepage_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:jason, ">= 1.0.0"},
      {:tesla, "~> 1.4.0"},
      {:mint, "~> 1.0"},
      {:castore, "~> 0.1"},
      {:poolboy, "~> 1.5"},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.12.2", only: [:test], runtime: false}
    ]
  end

  defp description do
    """
    Elixir client for ClickHouse, a fast open-source Online Analytical
    Processing (OLAP) database management system.
    """
  end

  defp package do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "pillar",
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/balance-platform/pillar"}
    ]
  end

  defp aliases do
    [
      test: ["format --check-formatted", "test"],
      check_code: ["credo", "format", "dialyzer"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
