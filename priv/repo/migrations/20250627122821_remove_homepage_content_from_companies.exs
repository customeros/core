defmodule Core.Repo.Migrations.RemoveHomepageContentFromCompanies do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      remove(:homepage_content)
    end
  end

  def down do
    alter table(:companies) do
      add(:homepage_content, :text)
    end
  end
end
