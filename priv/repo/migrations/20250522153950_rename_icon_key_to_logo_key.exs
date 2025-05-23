defmodule Core.Repo.Migrations.RenameIconKeyToLogoKey do
  use Ecto.Migration

  def up do
    rename table(:companies), :icon_key, to: :logo_key
  end

  def down do
    rename table(:companies), :logo_key, to: :icon_key
  end
end
