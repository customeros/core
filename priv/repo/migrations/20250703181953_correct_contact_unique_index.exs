defmodule Core.Repo.Migrations.CorrectContactUniqueIndex do
  use Ecto.Migration

  def up do
    # Drop the existing unique index on linkedin_id alone
    drop_if_exists index(:contacts, [:linkedin_id], name: :contacts_linkedin_id_index)

    # Add new composite unique index on linkedin_id and linkedin_company_id
    create unique_index(:contacts, [:linkedin_id, :linkedin_company_id], name: :contacts_linkedin_id_company_id_index)
  end

  def down do
    # Drop the composite unique index
    drop_if_exists index(:contacts, [:linkedin_id, :linkedin_company_id], name: :contacts_linkedin_id_company_id_index)

    # Restore the original unique index on linkedin_id alone
    create unique_index(:contacts, [:linkedin_id], name: :contacts_linkedin_id_index)
  end
end
