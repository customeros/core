defmodule Core.Repo.Migrations.RemoveContactEmailConstraints do
  use Ecto.Migration

  def up do
    # Remove the unique constraint on business_email
    drop_if_exists unique_index(:contacts, [:business_email], where: "business_email IS NOT NULL")
  end

  def down do
    # Restore the unique constraint on business_email
    create unique_index(:contacts, [:business_email], where: "business_email IS NOT NULL")
  end
end
