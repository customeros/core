defmodule Core.Repo.Migrations.AddErrorMessageToLeadsTable do
  use Ecto.Migration

  def up do
    alter table(:leads) do
      add :error_message, :text
    end
  end

  def down do
    alter table(:leads) do
      remove :error_message
    end
  end
end
