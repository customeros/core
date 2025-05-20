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
  pubsub_server: Core.Realtime.PubSub,
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

# External services and integrations
config :core,
  nats: [
    environment: "dev",
    nats_node_1: "localhost",
    nats_node_2: "localhost",
    nats_node_3: "localhost",
    nats_port: 4222
  ],
  ai: %{
    anthropic_api_path: "https://api.anthropic.com/v1/messages",
    default_llm_timeout: 45_000
  }

# Import environment specific config
import_config "#{config_env()}.exs"
