defmodule Core.Repo.Migrations.CreateLeadsTable do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE lead_type AS ENUM ('contact', 'company')",
            "DROP TYPE lead_type"

    execute "CREATE TYPE lead_stage AS ENUM ('target', 'education', 'solution', 'evaluation', 'ready_to_buy')",
            "DROP TYPE lead_stage"

    create table(:leads, primary_key: false) do
      add :id, :string, null: false
      add :tenant_id, :string, null: false
      add :ref_id, :string, null: false
      add :type, :lead_type, null: false
      add :stage, :lead_stage, null: false, default: "target"

      timestamps()
    end
  end
end
