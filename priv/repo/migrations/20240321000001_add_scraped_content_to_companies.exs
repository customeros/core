defmodule Core.Repo.Migrations.AddScrapedContentToCompanies do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      # Using text type for potentially large content
      add :scraped_content, :text
    end
  end
end
