defmodule :"Elixir.Core.Repo.Migrations.Update-lead-stage-enums" do
  use Ecto.Migration

  def up do
    # Add new values to the existing lead_stage enum
    execute("ALTER TYPE lead_stage ADD VALUE 'customer'")
    execute("ALTER TYPE lead_stage ADD VALUE 'not_a_fit'")

    # Create new icp_fit enum
    execute("""
    CREATE TYPE icp_fit AS ENUM ('strong', 'moderate')
    """)

    # Add icp_fit column to leads table
    alter table(:leads) do
      add(:icp_fit, :icp_fit, null: true)
    end
  end

  def down do
    # Remove icp_fit column and enum
    alter table(:leads) do
      remove(:icp_fit)
    end

    execute("DROP TYPE icp_fit")

    # PostgreSQL doesn't support removing enum values directly
    # We need to recreate the enum without the new values

    # First, update any records with 'customer' or 'not_a_fit' to 'target'
    # This is necessary because the original enum doesn't have these values
    execute("""
    UPDATE leads
    SET stage = 'target'
    WHERE stage IN ('customer', 'not_a_fit')
    """)

    # Remove the default constraint temporarily
    execute("ALTER TABLE leads ALTER COLUMN stage DROP DEFAULT")

    # Rename the current enum
    execute("ALTER TYPE lead_stage RENAME TO lead_stage_old")

    # Create the new enum with original values only
    execute("""
    CREATE TYPE lead_stage AS ENUM ('target', 'education', 'solution', 'evaluation', 'ready_to_buy')
    """)

    # Update the table to use the new enum type
    execute("""
    ALTER TABLE leads
    ALTER COLUMN stage TYPE lead_stage
    USING stage::text::lead_stage
    """)

    # Restore the default value
    execute("ALTER TABLE leads ALTER COLUMN stage SET DEFAULT 'target'")

    # Drop the old enum
    execute("DROP TYPE lead_stage_old")
  end
end
