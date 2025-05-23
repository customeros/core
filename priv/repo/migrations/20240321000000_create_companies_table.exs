defmodule Core.Repo.Migrations.CreateCompaniesTable do
  use Ecto.Migration

  def change do
    create table(:companies, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:primary_domain, :string, null: false)
      add(:name, :string)
      add(:industry_code, :string)
      add(:industry, :string)
      add(:icon_key, :string)
      add(:country_a2, :string)

      timestamps()
    end

    create(unique_index(:companies, [:primary_domain]))
  end
end
