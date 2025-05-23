defmodule Core.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users, primary_key: false) do
      add :id, :string, primary_key: true
      add :email, :citext, null: false
      add :tenant_id, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])

    create table(:users_tokens, primary_key: false) do
      add :id, :string, primary_key: true
      add :user_id, :string, null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end

  def down do
    drop unique_index(:users_tokens, [:context, :token])
    drop index(:users_tokens, [:user_id])
    drop table(:users_tokens)

    drop unique_index(:users, [:email])
    drop table(:users)

    execute "DROP EXTENSION IF EXISTS citext"
  end
end
