defmodule Core.Repo.Migrations.AddUsedAtToUsersTokens do
  use Ecto.Migration

  def up do
    # Add used_at column
    alter table(:users_tokens) do
      add :used_at, :utc_datetime
      add :alert_sent, :boolean, default: false, null: false
    end

    # Populate existing magic_link tokens with current timestamp
    execute """
    UPDATE users_tokens
    SET used_at = NOW()
    WHERE context = 'magic_link'
    """
  end

  def down do
    alter table(:users_tokens) do
      remove :used_at
      remove :alert_sent
    end
  end
end
