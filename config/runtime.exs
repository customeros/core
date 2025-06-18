import Config

# Helper functions for environment variables
get_env = fn key, default -> System.get_env(key, default) end

get_env_integer = fn key, default ->
  String.to_integer(get_env.(key, default))
end

get_env_boolean = fn key, default ->
  case get_env.(key, default) do
    val when val in ["true", "1"] -> true
    _ -> false
  end
end

# Load environment variables from .env in development
if config_env() == :dev do
  case File.read(".env") do
    {:ok, content} ->
      content
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != "" && !String.starts_with?(&1, "#")))
      |> Enum.each(fn line ->
        [key, value] = String.split(line, "=", parts: 2)
        System.put_env(key, value)
      end)

    _ ->
      :ok
  end
end

# Server configuration
if get_env.("PHX_SERVER", nil),
  do: config(:core, Web.Endpoint, server: true)

# Database configuration
config :core, Core.Repo,
  username: get_env.("POSTGRES_USER", "postgres"),
  password: get_env.("POSTGRES_PASSWORD", "password"),
  hostname: get_env.("POSTGRES_HOST", "localhost"),
  database: get_env.("POSTGRES_DB", "customeros"),
  port: get_env_integer.("POSTGRES_PORT", "5555"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :core, :analytics,
  posthog_key: get_env.("POSTHOG_KEY", nil),
  posthog_host: get_env.("POSTHOG_HOST", "https://app.posthog.com")

# Support configuration
config :core, :support, atlas_app_id: get_env.("ATLAS_APP_ID", nil)

# OpenTelemetry configuration (traces only - keep it simple)
config :opentelemetry,
       :processors,
       if(System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT"),
         do: [
           otel_batch_processor: %{
             exporter: {
               :opentelemetry_exporter,
               %{endpoints: [System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT")]}
             }
           }
         ],
         else: []
       )

# File-based logging configuration
config :logger,
  backends: [{LoggerFileBackend, :info_log}]

config :logger, :info_log,
  path: "/app/logs/app.log",
  level: :info,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id]

config :logger, :default_handler,
  config: %{
    formatter: {OpenTelemetry.Logger.Formatter, []}
  }

# IPData and Snitcher configuration
config :core, :ipdata,
  api_key: get_env.("IPDATA_API_KEY", nil),
  api_url: "https://api.ipdata.co"

config :core, :snitcher,
  api_url: "https://api.snitcher.com",
  api_key: get_env.("SNITCHER_API_KEY", nil)

# AI configuration
config :core, :ai,
  anthropic_api_path: "https://api.anthropic.com/v1/messages",
  anthropic_api_key: get_env.("ANTHROPIC_API_KEY", nil),
  gemini_api_path:
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
  gemini_api_key: get_env.("GEMINI_API_KEY", nil),
  groq_api_path: "https://api.groq.com/openai/v1/chat/completions",
  groq_api_key: get_env.("GROQ_API_KEY", nil)

# Production environment specific configuration
if config_env() == :prod do
  if System.get_env("NODE_NAME") do
    Application.put_env(:kernel, :inet_dist_listen_min, 9100)
    Application.put_env(:kernel, :inet_dist_listen_max, 9155)
  end

  config :libcluster,
    debug: get_env_boolean.("LIBCLUSTER_DEBUG", "false")

  secret_key_base =
    get_env.("SECRET_KEY_BASE", nil) ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = get_env.("PHX_HOST", "example.com")
  port = get_env_integer.("PORT", "4000")

  nodes =
    System.get_env("CLUSTER_NODES", "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.to_atom/1)

  if length(nodes) > 0 do
    config :libcluster, :topologies,
      static: [
        strategy: Cluster.Strategy.Static,
        config: [nodes: nodes]
      ]
  end

  config :core, Web.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end

# Jina configuration
config :core, :jina,
  jina_api_path: "https://r.jina.ai/",
  jina_api_key: get_env.("JINA_API_KEY", nil)

config :core, :firecrawl, firecrawl_api_key: get_env.("FIRECRAWL_API_KEY", nil)

# PureMD configuration
config :core, :puremd,
  puremd_api_path: "https://pure.md/",
  puremd_api_key: get_env.("PUREMD_API_KEY", nil)

if get_env.("POSTMARK_API_KEY", nil) in [nil, ""] do
  config :swoosh, :api_client, false
  config :core, Core.Mailer, adapter: Swoosh.Adapters.Local
else
  config :swoosh, local: false

  config :core, Core.Mailer,
    adapter: Swoosh.Adapters.Postmark,
    api_key: System.get_env("POSTMARK_API_KEY", "")
end

# R2 configuration
config :core, :r2,
  account_id: System.get_env("CLOUDFLARE_R2_ACCOUNT_ID"),
  access_key_id: System.get_env("CLOUDFLARE_R2_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("CLOUDFLARE_R2_ACCESS_KEY_SECRET"),
  region: "auto",
  images: [
    bucket: "images",
    cdn_domain: System.get_env("R2_IMAGES_CDN")
  ]

# ExAws configuration for R2
config :ex_aws, :s3,
  access_key_id: System.get_env("CLOUDFLARE_R2_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("CLOUDFLARE_R2_ACCESS_KEY_SECRET"),
  region: "auto",
  scheme: "https://",
  host:
    "#{System.get_env("CLOUDFLARE_R2_ACCOUNT_ID")}.r2.cloudflarestorage.com",
  json_codec: Jason

# Configure ExAws to use our custom HTTP client
config :ex_aws, :http_client, Core.Utils.HttpClient.AwsHttpClient

# Brandfetch configuration
config :core, :brandfetch, client_id: get_env.("BRANDFETCH_CLIENT_ID", nil)

# Slack configuration
config :core, :slack,
  enabled: true,
  new_tenant_webhook_url: get_env.("SLACK_NEW_TENANT_WEBHOOK_URL", nil),
  new_user_webhook_url: get_env.("SLACK_NEW_USER_WEBHOOK_URL", nil),
  daily_lead_summary_webhook_url:
    get_env.("SLACK_DAILY_LEAD_SUMMARY_WEBHOOK_URL", nil),
  crash_webhook_url: get_env.("SLACK_CRASH_WEBHOOK_URL", nil),
  error_webhook_url: get_env.("SLACK_CRASH_WEBHOOK_URL", nil),
  alerts_prospects_webhook_url: get_env.("SLACK_PROSPECTS_ALERT_URL", nil)

config :core, :mailsherpa,
  mailsherpa_api_url: get_env.("MAILSHERPA_API_URL", nil),
  mailsherpa_api_key: get_env.("MAILSHERPA_API_KEY", nil)

# HubSpot Integration Configuration
config :core, :hubspot,
  client_id: System.get_env("HUBSPOT_CLIENT_ID"),
  client_secret: System.get_env("HUBSPOT_CLIENT_SECRET"),
  scopes: String.split(System.get_env("HUBSPOT_SCOPES", ""), " "),
  api_base_url: "https://api.hubapi.com",
  auth_base_url: "https://app.hubspot.com",
  app_id: System.get_env("HUBSPOT_APP_ID") || "14153034",
  webhook_uri:
    System.get_env("HUBSPOT_WEBHOOK_URI") ||
      "https://app.customeros.ai/hubspot/webhook"

config :core, :scrapin,
  scrapin_api_key: System.get_env("SCRAPIN_API_KEY"),
  scrapin_base_url:
    System.get_env("SCRAPIN_BASE_URL") || "https://api.scrapin.io"

# Validate required HubSpot configuration
if config_env() == :prod do
  required_env_vars = [
    "HUBSPOT_CLIENT_ID",
    "HUBSPOT_CLIENT_SECRET"
  ]

  Enum.each(required_env_vars, fn var ->
    if is_nil(System.get_env(var)) do
      raise """
      environment variable #{var} is missing.
      This variable is required for HubSpot integration in production.
      """
    end
  end)
end
