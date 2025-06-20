import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :core, Core.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "password"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  port: System.get_env("POSTGRES_PORT", "5555"),
  database: "core_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :core, Web.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false,
  secret_key_base: String.duplicate("a", 64)

# In test we don't send emails.
config :core, Core.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Configure IPData service to use mock in test
config :core, :ipdata,
  api_key: "test-key",
  api_url: "http://test-url"

# Use mock for IPData service in test
config :core, Core.External.IPData.Service, Core.External.IPData.Service.Mock

# Use mock for IPIntelligence in test
config :core,
       Core.WebTracker.IPIntelligence,
       Core.WebTracker.IPIntelligence.Mock

# Configure service mocks for test
config :core, :jina_service, Core.External.Jina.Service.Mock
config :core, :puremd_service, Core.External.Puremd.Service.Mock
config :core, :classify_service, Core.Ai.Webpage.Classify.Mock
config :core, :profile_intent_service, Core.Ai.Webpage.ProfileIntent.Mock

config :core, :slack, enabled: false, webhook_url: "https://dummy-url.com"

# Configure MIME types
config :mime, :types, %{
  "application/json" => ["json"]
}

# URL configuration for test
config :core, :url,
  scheme: "http",
  host: "localhost:4002"
