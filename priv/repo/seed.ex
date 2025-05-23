# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seed.exs
#
# Inside the script, you can read and write to any database.
#
defmodule Core.Repo.Migrations.CreateLeadsForCompanies do
  use Ecto.Migration

  def change do
    execute("""
    INSERT INTO leads (id, tenant_id, ref_id, type, stage, inserted_at, updated_at)
    SELECT
      id,
      'tenant_0l1p22vquxhq5dj6',
      id,
      'company',
      'target',
      inserted_at,
      updated_at
    FROM companies c
    WHERE NOT EXISTS (
      SELECT 1 FROM leads WHERE ref_id = c.id
    );
    """)
  end
end
