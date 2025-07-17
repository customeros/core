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
  backends: [
    :console,
    Core.Notifications.CrashMonitor,
    {Core.Logger.SignozUdpLogger,
     [
       host: System.get_env("SIGNOZ_UDP_HOST", "10.0.16.2"),
       port: String.to_integer(System.get_env("SIGNOZ_UDP_PORT", "54525")),
       env: System.get_env("OTEL_ENVIRONMENT", "production"),
       service_name: System.get_env("OTEL_SERVICE_NAME", "customeros-core"),
       batch_size: 50,
       batch_timeout: 2_000
     ]}
  ],
  level: :warning

config :core, :app_env, :prod

# Enable cron jobs in production
config :core, :crons, enabled: true
