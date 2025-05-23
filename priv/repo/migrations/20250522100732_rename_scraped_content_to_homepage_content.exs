defmodule Core.Repo.Migrations.RenameScrapedContentToHomepageContent do
  use Ecto.Migration

  def up do
    rename table(:companies), :scraped_content, to: :homepage_content
  end

  def down do
    rename table(:companies), :homepage_content, to: :scraped_content
  end
end
