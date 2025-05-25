import Config

config :core, Web.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  check_origin: [
    "https://preview.customeros.ai"
  ]

config :logger, level: :info

config :core, :app_env, :prod
