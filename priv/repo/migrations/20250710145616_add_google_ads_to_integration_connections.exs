defmodule Core.Repo.Migrations.AddGoogleAdsToIntegrationConnections do
  use Ecto.Migration

  def up do
    # Add google_ads to the provider enum
    execute "ALTER TYPE integration_connections_provider_enum ADD VALUE 'google_ads'"
  end

  def down do
    # Note: PostgreSQL doesn't support removing enum values directly
    # This would require recreating the enum type, which is complex
    # For now, we'll leave the enum value in place
    # If needed, this could be handled by recreating the table
    execute "SELECT 'google_ads enum value remains - manual cleanup may be required'"
  end
end
