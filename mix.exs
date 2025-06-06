defmodule Core.MixProject do
  use Mix.Project

  def project do
    [
      app: :core,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: [
        core: [
          applications: [opentelemetry: :temporary],
          include_executables_for: [:unix],
          strip_beams: Mix.env() == :prod
        ]
      ],
      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_add_apps: [
          :mix,
          :ex_unit,
          :ecto,
          :ecto_sql,
          :mint,
          :finch,
          :phoenix,
          :phoenix_template,
          :phoenix_ecto,
          :phoenix_html,
          :phoenix_live_view,
          :telemetry
        ]
      ]
    ]
  end

  def application do
    [
      mod: {Core.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon, :recon]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:absinthe, "~> 1.7"},
      {:absinthe_plug, "~> 1.5"},
      {:amqp, "~> 4.0"},
      {:bandit, "~> 1.2"},
      {:castore, "~> 1.0"},
      {:cors_plug, "~> 3.0"},
      {:cowlib, "~> 2.15", override: true},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:csv, "~> 3.2"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dns_cluster, "~> 0.2.0"},
      {:earmark, "~> 1.4"},
      {:ecto_psql_extras, "~> 0.8"},
      {:ecto_sql, "~> 3.12"},
      {:floki, "~> 0.37.1"},
      {:finch, "~> 0.19"},
      {:gnat, "~> 1.10"},
      {:grpc, "~> 0.10.1"},
      {:gettext, "~> 0.20"},
      {:idna, "~> 6.1.1"},
      {:jason, "~> 1.4"},
      {:jetstream, "~> 0.0.9"},
      {:mox, "~> 1.1", only: :test},
      {:nanoid, "~> 2.1.0"},
      {:opentelemetry, "~> 1.5"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_bandit, "~> 0.2"},
      {:opentelemetry_exporter, "~> 1.8"},
      {:opentelemetry_phoenix, "~> 2.0"},
      {:opentelemetry_ecto, "~> 1.2.0"},
      {:phoenix, "~> 1.7.20"},
      {:phoenix_ecto, "~> 4.6"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_dashboard, "~> 0.8.6"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.5"},
      {:phoenix_pubsub, "~> 2.1.3"},
      {:plug, "~> 1.18", override: true},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, "~> 0.20"},
      {:protobuf_generate, "~> 0.1.3", runtime: false},
      {:stream_data, "~> 1.2"},
      {:swoosh, "~> 1.19"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.0"},
      {:temp, "~> 0.4"},
      {:y_ex, "~> 0.7"},
      {:inertia, "~> 2.4.0"},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:sweet_xml, "~> 0.7"},
      {:countriex, "~> 0.4.1"}
    ]
  end

  defp aliases do
    [
      clean_deps: ["deps.clean --unused --unlock"],
      dev: ["compile.script", "phx.server", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.seed": ["run priv/repo/seeds.exs"],
      proto: ["proto.fetch", "proto.gen"],
      setup: [
        "deps.get",
        "ecto.setup"
      ],
      check: ["compile", "format", "credo", "dialyzer"],
      tidy: ["deps.get"],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "cmd npm install --prefix assets"
      ],
      "assets.build": ["tailwind core", "esbuild core"],
      "assets.deploy": [
        "tailwind core --minify",
        "esbuild core --minify",
        "phx.digest"
      ]
    ]
  end
end
