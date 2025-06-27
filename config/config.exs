import Config
get_env = fn key, default -> System.get_env(key, default) end

# Core application
config :core,
  ecto_repos: [Core.Repo],
  generators: [timestamp_type: :utc_datetime],
  app_env: config_env()

# OpenTelemetry configuration for SigNoz
config :opentelemetry, :resource,
  service: %{name: System.get_env("OTEL_SERVICE_NAME", "customeros-core")}

# Web endpoint
config :core, Web.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: Web.ErrorHTML, json: Web.ErrorJSON],
    layout: false
  ],
  pubsub_server: Core.PubSub,
  live_view: [signing_salt: "jVLoUB9r"]

# Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :body,
    :cache_key,
    :company,
    :company_id,
    :company_domain,
    :domain,
    :email,
    :error,
    :event_type,
    :external_id,
    :function,
    :icp_fit,
    :ip,
    :lead_id,
    :leads_count,
    :message,
    :module,
    :name,
    :reason,
    :request_id,
    :response,
    :result,
    :session_id,
    :status,
    :tenant_id,
    :trace_id,
    :url,
    :user_id
  ]

# Phoenix
config :phoenix, :json_library, Jason

# Mailer
config :swoosh,
  api_client: Swoosh.ApiClient.Finch,
  finch_name: Core.Finch

# External services and integrations
config :core, Core.Repo,
  ai: [
    anthropic_api_path: "https://api.anthropic.com/v1/messages",
    default_llm_timeout: 45_000
  ],
  support: [
    atlas_app_id: get_env.("ATLAS_APP_ID", nil)
  ]

# Analytics configuration
config :core, :analytics,
  posthog_key: get_env.("POSTHOG_KEY", nil),
  posthog_host: get_env.("POSTHOG_HOST", "https://app.posthog.com")

# Esbuild configuration
config :esbuild,
  version: "0.21.5",
  core: [
    args:
      ~w(src/app.tsx --bundle --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --splitting --format=esm --jsx=automatic --loader:.png=copy --loader:.jpg=copy --loader:.jpeg=copy --loader:.svg=copy),
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
  camelize_props: false,
  preserve_case: true,
  static_paths: ["/assets/app.js"],
  default_version: "1",
  ssr: false,
  raise_on_ssr_failure: true,
  page_title: true,
  props: %{
    page_title: "CustomerOS"
  }

# Cron jobs configuration
config :core, :crons, enabled: true

# Import environment specific config
import_config "#{config_env()}.exs"
