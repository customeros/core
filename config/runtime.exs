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
  gemini_api_key: get_env.("GEMINI_API_KEY", nil)

# Production environment specific configuration
if config_env() == :prod do
  secret_key_base =
    get_env.("SECRET_KEY_BASE", nil) ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = get_env.("PHX_HOST", "example.com")
  port = get_env_integer.("PORT", "4000")

  config :core, :dns_cluster_query, get_env.("DNS_CLUSTER_QUERY", nil)

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
  new_tenant_webhook_url: get_env.("SLACK_NEW_TENANT_WEBHOOK_URL", nil),
  new_user_webhook_url: get_env.("SLACK_NEW_USER_WEBHOOK_URL", nil),
  crash_webhook_url: get_env.("SLACK_CRASH_WEBHOOK_URL", nil)
