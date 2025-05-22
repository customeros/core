defmodule Core.Repo.Migrations.RenameScrapedContentToHomepageContent do
  use Ecto.Migration

  def change do
    rename table(:companies), :scraped_content, to: :homepage_content
  end
end
