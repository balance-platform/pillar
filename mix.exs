defmodule Pillar.MixProject do
  use Mix.Project

  @source_url "https://github.com/balance-platform/pillar"
  @version "0.40.0"

  def project do
    [
      app: :pillar,
      name: "Pillar",
      aliases: aliases(),
      version: @version,
      elixir: "~> 1.15",
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
      {:tesla, ">= 1.4.0"},
      {:mint, ">= 1.4.0"},
      {:castore, ">= 0.1.0"},
      {:poolboy, "~> 1.5"},
      {:decimal, ">= 1.0.0"},
      {:tzdata, "~> 1.1", only: [:dev, :test]},
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.21.0", only: [:dev], runtime: false},
      {:excoveralls, ">= 0.12.2", only: [:test], runtime: false}
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
      files: ~w(lib .formatter.exs mix.exs README* stuff/*),
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

      # Additional metadata
      authors: [
        "Dmitry Shpagin",
        "Maintainer balance-platform/pillar",
        "Aleksei Matiushkin",
        "Contributors from balance-platform/pillar",
        "Aleksey Redkin",
        "Contributors from balance-platform/pillar"
      ],

      # Document Organization
      extras: [
        "README.md": [title: "Overview"],
        "stuff/guides/getting_started.md": [title: "Getting Started"],
        "stuff/guides/connection_pool.md": [title: "Connection Pool"],
        "stuff/guides/migrations.md": [title: "Migrations"],
        "stuff/guides/bulk_inserts.md": [title: "Bulk Insert Strategies"],
        "stuff/advanced/custom_types.md": [title: "Custom Type Conversions"],
        "stuff/advanced/http_adapters.md": [title: "HTTP Adapters"],
        "stuff/troubleshooting.md": [title: "Troubleshooting"]
      ],

      # Document Groups for Navigation
      groups_for_extras: [
        Guides: ~r/guides\//,
        "Advanced Usage": ~r/advanced\//,
        Troubleshooting: ~r/troubleshooting/
      ],

      # Module Organization
      groups_for_modules: [
        Core: [
          Pillar,
          Pillar.Connection
        ],
        "Query Building & Execution": [
          Pillar.QueryBuilder,
          Pillar.ResponseParser
        ],
        "Bulk Operations": [
          Pillar.BulkInsertBuffer
        ],
        Migrations: [
          Pillar.Migrations.Generator,
          Pillar.MigrationsMacro
        ],
        "HTTP Client": [
          Pillar.HttpClient.Adapter,
          Pillar.HttpClient.Response,
          Pillar.HttpClient.TransportError
        ],
        "Type Conversion": [
          Pillar.TypeConvert.ToClickhouse,
          Pillar.TypeConvert.ToClickhouseJson,
          Pillar.TypeConvert.ToElixir
        ]
      ],

      # Skip warnings for undefined references
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],

      # Format specific options
      formatters: ["html"],

      # Before closing HTML tag in head
      before_closing_head_tag: &before_closing_head_tag/1
    ]
  end

  # Add custom JavaScript or CSS if needed
  defp before_closing_head_tag(:html) do
    """
    <style>
      /* Custom CSS for documentation */
      .content-inner {
        max-width: 80ch;
        margin: 0 auto;
      }
      .sidebar-header {
        margin-bottom: 1rem;
      }
    </style>
    """
  end

  defp before_closing_head_tag(_), do: ""
end
