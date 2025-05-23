defmodule Core.Repo.Migrations.CreateLeadsTable do
  use Ecto.Migration

  def up do
    execute """
    CREATE TYPE lead_type AS ENUM ('contact', 'company')
    """

    execute """
    CREATE TYPE lead_stage AS ENUM ('target', 'education', 'solution', 'evaluation', 'ready_to_buy')
    """

    create table(:leads, primary_key: false) do
      add :id, :string, null: false
      add :tenant_id, :string, null: false
      add :ref_id, :string, null: false
      add :type, :lead_type, null: false
      add :stage, :lead_stage, null: false, default: "target"

      timestamps()
    end
  end

  def down do
    drop table(:leads)
    execute "DROP TYPE lead_stage"
    execute "DROP TYPE lead_type"
  end
end
