defmodule Core.Repo.Migrations.AddUniqueIndexToLeads do
  use Ecto.Migration

  def up do
    create unique_index(:leads, [:tenant_id, :ref_id, :type], name: :leads_tenant_ref_type_unique_index)
  end

  def down do
    drop index(:leads, [:tenant_id, :ref_id, :type], name: :leads_tenant_ref_type_unique_index)
  end
end
