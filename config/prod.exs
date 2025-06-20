import Config

config :core, Web.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  check_origin: [
    "https://app.customeros.ai"
  ]

# URL configuration for production
config :core, :url,
  scheme: "https",
  host: System.get_env("PHX_HOST", "app.customeros.ai")

config :logger,
  backends: [:console, Core.Notifications.CrashMonitor],
  level: :warning

config :core, :app_env, :prod

# Enable cron jobs in production
config :core, :crons, enabled: true
