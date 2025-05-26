defmodule Core.Repo.Migrations.CreateApiTokensTable do
  use Ecto.Migration

  def up do
    create table(:api_tokens, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:user_id, :string, null: false)
      add(:token, :binary, null: false)
      add(:name, :string, null: false)
      add(:last_used_at, :utc_datetime)
      add(:expires_at, :utc_datetime)
      add(:scopes, {:array, :string}, default: [])
      add(:active, :boolean, default: true, null: false)

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create(index(:api_tokens, [:user_id]))
    create(unique_index(:api_tokens, [:token]))
    create(index(:api_tokens, [:active]))
    create(index(:api_tokens, [:expires_at]))
    create(index(:api_tokens, [:user_id, :active]))
  end

  def down do
    drop(index(:api_tokens, [:user_id, :active]))
    drop(index(:api_tokens, [:expires_at]))
    drop(index(:api_tokens, [:active]))
    drop(unique_index(:api_tokens, [:token]))
    drop(index(:api_tokens, [:user_id]))
    drop(table(:api_tokens))
  end
end
