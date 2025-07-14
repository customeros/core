defmodule Core.Repo.Migrations.DropUniqueIndexFromTargetPersonaLinkedinQueues do
  use Ecto.Migration

  def up do
    drop_if_exists index(:target_persona_linkedin_queues, [:tenant_id, :linkedin_url], unique: true)
  end

  def down do
    create unique_index(:target_persona_linkedin_queues, [:tenant_id, :linkedin_url])
  end
end
