defmodule Pillar.MixProject do
  use Mix.Project

  def project do
    [
      app: :pillar,
      aliases: aliases(),
      version: "0.16.0",
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
      source_url: "https://github.com/CatTheMagician/pillar",
      name: "Pillar",
      source_url: "https://github.com/CatTheMagician/pillar",
      homepage_url: "https://github.com/CatTheMagician/pillar",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, ">= 1.0.0"},
      {:poolboy, "~> 1.5"},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.12.2", only: :test, runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description() do
    "Clickhouse client"
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "pillar",
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/CatTheMagician/pillar"}
    ]
  end

  defp aliases() do
    [
      test: ["format --check-formatted", "test"],
      check_code: ["credo", "format", "dialyzer"]
    ]
  end
end
