defmodule Core.Repo.Migrations.RenameIconKeyToLogoKey do
  use Ecto.Migration

  def change do
    rename table(:companies), :icon_key, to: :logo_key
  end
end
