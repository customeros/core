defmodule Core.Crm.Leads do
  @moduledoc """
  The Leads context.
  """

  import Ecto.Query, warn: false
  alias Core.Repo
  alias Core.Crm.Leads.Lead
  alias Core.Auth.Tenants

  def get_by_ref_id(tenant_id, ref_id) do
    Repo.get_by(Lead, tenant_id: tenant_id, ref_id: ref_id)
  end

  def list_by_tenant_id(tenant_id) do
    Repo.all(Lead, where: [tenant_id: tenant_id])
  end

  def get_or_create(tenant, attrs) do
    case Tenants.get_tenant_by_name(tenant) do
      nil ->
        {:error, :not_found, "Tenant not found"}

      %Tenants.Tenant{id: tenant_id} ->
        case get_by_ref_id(tenant_id, attrs.ref_id) do
          nil ->
            %Lead{}
            |> Lead.changeset(%{
              tenant_id: tenant_id,
              ref_id: attrs.ref_id,
              type: attrs.type,
              stage: Map.get(attrs, :stage, :target)
            })
            |> Repo.insert()

          lead ->
            {:ok, lead}
        end
    end
  end

  def update_lead(%Lead{} = lead, attrs) do
    lead
    |> Lead.changeset(attrs)
    |> Repo.update()
  end
end
