defmodule Core.Repo.Migrations.AddProductsToTenantsTable do
  use Ecto.Migration

  def change do
    alter table(:tenants) do
      add :products, {:array, :string}, default: []
    end
  end
end
