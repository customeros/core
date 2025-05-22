import Config

config :core, Web.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  check_origin: [
    "https://app.customeros.dev",
    "https://app.customeros.ai",
    "https://app.customeros.local",
    "https://frontera.customeros.ai",
    "https://frontera.openline.dev",
    "//*.localcan.dev"
  ]

config :logger, level: :info

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

config :core, Core.Mailer,
  adapter: Swoosh.Adapters.Postmark,
  api_key: "aa3f8b33-77af-4d81-b6ce-eb8d82346c6a"

config :core, :app_env, :prod
