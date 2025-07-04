defmodule Core.Repo.Migrations.UpdateColumnLengthForContacts do
  use Ecto.Migration

  def up do
    alter table(:contacts) do
      modify :summary, :text
      modify :headline, :text
      modify :job_description, :text
    end
  end

  def down do
    alter table(:contacts) do
      modify :summary, :string
      modify :headline, :string
      modify :job_description, :string
    end
  end
end
