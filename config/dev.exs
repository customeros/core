import Config

# Web endpoint configuration for development
config :core, Web.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    "YhZZx2x6lsMGrDZRg8cpZiRf9cQf6UWo9hz9wyqAb/5Ym+sc0cIfW5PS8yHi8hB5",
  watchers: [
    esbuild:
      {Esbuild, :install_and_run, [:core, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:core, ~w(--watch)]}
  ],
  reloadable_compilers: [:gettext, :elixir],
  reloadable_apps: [:ui, :backend],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :core, dev_routes: true

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Development-specific configurations
config :core, :realtime,
  dev_routes: true,
  app_env: :dev

# Development logger configuration
config :logger,
  backends: [:console]

config :logger, :console,
  level: :debug,
  format: "[$level] $message\n"

config :esbuild,
  version: "0.18.6",
  default: [
    args: ~w(js/app.js),
    cd: Path.expand("../assets", __DIR__)
  ]

# Phoenix development configurations
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view, :debug_heex_annotations, true

# Disable cron jobs in development by default
config :core, :crons, enabled: false
config :core, :app_env, :dev
