defmodule Core.Repo.Migrations.MigrateLinkedinIdToLinkedinIds do
  use Ecto.Migration
  import Ecto.Query

  def up do
    # Migrate existing linkedin_id values to linkedin_ids array
    # Only migrate non-nil and non-empty linkedin_id values
    execute """
    UPDATE companies
    SET linkedin_ids = ARRAY[linkedin_id]
    WHERE linkedin_id IS NOT NULL
    AND linkedin_id != ''
    AND (linkedin_ids IS NULL OR linkedin_ids = '{}' OR array_length(linkedin_ids, 1) IS NULL)
    """
  end

  def down do
    # This migration is not reversible as we can't determine which linkedin_id
    # was the original one from the array
    # The data would need to be restored from a backup if needed
  end
end
