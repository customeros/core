defmodule Core.Repo.Migrations.AddPendingStageToLeads do
  use Ecto.Migration

  def up do
    # First, we need to update the enum type to include :pending
    # Since PostgreSQL enums can't be modified directly when they're in use,
    # we need to create a new enum and migrate the data

    # Create new enum with pending included
    execute """
    CREATE TYPE lead_stage_new AS ENUM (
      'pending',
      'target', 
      'education',
      'solution',
      'evaluation',
      'ready_to_buy',
      'customer',
      'not_a_fit'
    )
    """

    # Add a temporary column with the new enum type
    alter table(:leads) do
      add :stage_new, :lead_stage_new, default: "pending"
    end

    # Copy data from old column to new column
    execute """
    UPDATE leads 
    SET stage_new = stage::text::lead_stage_new
    """

    # Drop the old column (this will free up the old enum type)
    alter table(:leads) do
      remove :stage
    end

    # NOW drop the old enum type (after the column is gone)
    execute "DROP TYPE lead_stage"

    # Rename the new enum type to the original name
    execute "ALTER TYPE lead_stage_new RENAME TO lead_stage"

    # Rename the new column to replace the old one
    rename table(:leads), :stage_new, to: :stage

    # Make sure the column has the correct default and constraints
    alter table(:leads) do
      modify :stage, :lead_stage, default: "pending", null: false
    end
  end

  def down do
    # Reverse the migration by removing :pending from the enum
    # This will fail if any records have stage = 'pending'

    # Update any pending records to target (or another appropriate default)
    execute """
    UPDATE leads 
    SET stage = 'target' 
    WHERE stage = 'pending'
    """

    # Create the old enum without pending
    execute """
    CREATE TYPE lead_stage_old AS ENUM (
      'target',
      'education', 
      'solution',
      'evaluation',
      'ready_to_buy',
      'customer',
      'not_a_fit'
    )
    """

    # Add temporary column
    alter table(:leads) do
      add :stage_old, :lead_stage_old, default: "target"
    end

    # Copy data
    execute """
    UPDATE leads 
    SET stage_old = stage::text::lead_stage_old
    """

    # Remove the current column
    alter table(:leads) do
      remove :stage
    end

    # Drop the current enum
    execute "DROP TYPE lead_stage"

    # Rename the old enum back
    execute "ALTER TYPE lead_stage_old RENAME TO lead_stage"

    # Rename the column back
    rename table(:leads), :stage_old, to: :stage

    # Set default back to whatever it was before
    alter table(:leads) do
      modify :stage, :lead_stage, default: "target", null: false
    end
  end
end
