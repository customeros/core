defmodule Core.Repo.Migrations.AddScrapedContentToCompanies do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      # Using text type for potentially large content
      add :scraped_content, :text
    end
  end

  def down do
    alter table(:companies) do
      remove :scraped_content
    end
  end
end
