defmodule Core.Repo.Migrations.UpdateIcpFitEnum do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TYPE icp_fit ADD VALUE 'not_a_fit'
    """)
  end

  def down do
    # Note: PostgreSQL doesn't support removing enum values directly
    # This would require recreating the enum type, which is complex
    # and potentially dangerous in production
    execute("""
    -- Cannot safely remove enum values in PostgreSQL
    -- Manual intervention required if rollback is needed
    """)
  end
end
