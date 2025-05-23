defmodule Core.Repo.Migrations.CreateIcpTable do
  use Ecto.Migration

  def change do
    create table(:ideal_customer_profiles) do
      add :domain, :string, null: false
      add :tenant_id, :string
      add :profile, :text, null: false
      add :qualifying_attributes, {:array, :string}, default: []

      timestamps()
    end

    # Indexes
    create unique_index(:ideal_customer_profiles, [:domain])
    create index(:ideal_customer_profiles, [:tenant_id])
  end
end
