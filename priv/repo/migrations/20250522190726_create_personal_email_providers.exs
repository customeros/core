defmodule Core.Repo.Migrations.CreatePersonalEmailProviders do
  use Ecto.Migration

  def change do
    create table(:personal_email_providers) do
      add :domain, :string, null: false
      add :inserted_at, :utc_datetime, null: false, default: fragment("CURRENT_TIMESTAMP")
    end

    create unique_index(:personal_email_providers, [:domain])
  end
end
