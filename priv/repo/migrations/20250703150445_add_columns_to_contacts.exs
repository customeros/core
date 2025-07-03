defmodule Core.Repo.Migrations.AddColumnsToContacts do
  use Ecto.Migration

  def up do
    # Rename description to job_description
    rename table(:contacts), :description, to: :job_description

    # Add new columns
    alter table(:contacts) do
      add :location, :string
      add :headline, :string
      add :summary, :string
    end
  end

  def down do
    # Remove new columns
    alter table(:contacts) do
      remove :location
      remove :headline
      remove :summary
    end

    # Rename job_description back to description
    rename table(:contacts), :job_description, to: :description
  end
end
