defmodule Core.Repo.Migrations.AddStateToLeads do
  use Ecto.Migration

  def up do
    # Create the enum type for lead state
    execute """
    CREATE TYPE lead_state AS ENUM (
      'not_contacted_yet',
      'outreach_in_progress',
      'meeting_booked'
    )
    """

    # Add the state column to the leads table
    alter table(:leads) do
      add :state, :lead_state, default: "not_contacted_yet"
    end

    # Add an index on the state column for faster queries
    create index(:leads, [:state])
  end

  def down do
    # Drop the index first
    drop index(:leads, [:state])

    # Remove the column
    alter table(:leads) do
      remove :state
    end

    # Drop the enum type
    execute "DROP TYPE lead_state"
  end
end
