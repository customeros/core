defmodule Core.Crm.Leads do
  @moduledoc """
  The Leads context.
  """

  import Ecto.Query, warn: false
  alias Core.Repo
  alias Core.Crm.Leads.{Lead, LeadView}
  alias Core.Auth.Tenants
  alias Core.Crm.Companies.Company
  alias Core.Media.Images

  @spec get_by_ref_id(tenant_id :: String.t(), ref_id :: String.t()) ::
          Lead.t() | nil
  def get_by_ref_id(tenant_id, ref_id) do
    Repo.get_by(Lead, tenant_id: tenant_id, ref_id: ref_id)
  end

  @spec list_by_tenant_id(tenant_id :: String.t()) :: [Lead.t()]
  def list_by_tenant_id(tenant_id) do
    Repo.all(Lead, where: [tenant_id: tenant_id])
  end

  @spec list_view_by_tenant_id(tenant_id :: String.t()) :: [LeadView.t()]
  def list_view_by_tenant_id(tenant_id) do
    from(l in Lead,
      where: l.tenant_id == ^tenant_id and l.type == :company,
      join: c in Company,
      on: c.id == l.ref_id,
      select: %{
        id: l.id,
        ref_id: l.ref_id,
        type: l.type,
        stage: l.stage,
        name: c.name,
        industry: c.industry,
        domain: c.primary_domain,
        country: c.country_a2,
        logo: Images.get_cdn_url(c.logo_key)
      }
    )
    |> Repo.all()
    |> Enum.map(&struct(LeadView, &1))
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
