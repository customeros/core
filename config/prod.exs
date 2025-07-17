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
    {Core.Logger.SignozLogger, [
      env: System.get_env("OTEL_ENVIRONMENT", "production"),
      endpoint: System.get_env("SIGNOZ_LOGS_ENDPOINT", "http://10.0.16.2:4318/v1/logs"),
      service_name: System.get_env("OTEL_SERVICE_NAME", "customeros-core")
    ]}
  ],
  level: :warning

config :core, :app_env, :prod

# Enable cron jobs in production
config :core, :crons, enabled: true
