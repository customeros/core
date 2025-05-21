import Config

# Core application
config :core,
  ecto_repos: [Core.Repo],
  generators: [timestamp_type: :utc_datetime]

# Web endpoint
config :core, Web.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: Web.ErrorHTML, json: Web.ErrorJSON],
    layout: false
  ],
  pubsub_server: Realtime.PubSub,
  live_view: [signing_salt: "jVLoUB9r"]

# Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Phoenix
config :phoenix, :json_library, Jason

# OpenTelemetry
config :opentelemetry, :processors,
  otel_batch_processor: %{
    exporter: {:otel_exporter_stdout, []}
  }

# Mailer
config :core, Core.Mailer, adapter: Swoosh.Adapters.Local

# External services and integrations
config :core,
  ai: [
    anthropic_api_path: "https://api.anthropic.com/v1/messages",
    default_llm_timeout: 45_000
  ],
  jina: [
    jina_api_path: "https://r.jina.ai/",
    jina_api_key: System.get_env("JINA_API_KEY")
  ],
  ipdata: [
    ipdata_api_key: System.get_env("IPDATA_API_KEY")
  ]

# Esbuild configuration
config :esbuild,
  version: "0.21.5",
  core: [
    args:
      ~w(ts/app.tsx --bundle --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --splitting --format=esm --jsx=automatic),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.0",
  core: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

 
# Inertia configuration
config :inertia,
  endpoint: Web.Endpoint,
  camelize_props: true,
  static_paths: ["/assets/app.js"],
  default_version: "1",
  ssr: false,
  raise_on_ssr_failure: true


# Import environment specific config
import_config "#{config_env()}.exs"

