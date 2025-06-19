defmodule Core.Repo.Migrations.AddWebtrackerStatusColumnToTenants do
  use Ecto.Migration

  def up do
    # Create the enum type
    execute("CREATE TYPE webtracker_status AS ENUM ('available', 'not_available')")

    # Add the column with a default value
    alter table(:tenants) do
      add(:webtracker_status, :webtracker_status,
        default: "not_available",
        null: false
      )
    end
  end

  def down do
    # Remove the column
    alter table(:tenants) do
      remove(:webtracker_status)
    end

    # Drop the enum type
    execute("DROP TYPE webtracker_status")
  end
end
