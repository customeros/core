defmodule Core.Crm.Leads do
  @moduledoc """
  The Leads context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Repo
  alias Core.Repo
  alias Core.Crm.Leads.{Lead, LeadView}
  alias Core.Auth.Tenants
  alias Core.Crm.Companies.Company
  alias Core.Utils.Media.Images

  @spec get_by_ref_id(tenant_id :: String.t(), ref_id :: String.t()) ::
          {:ok, Lead.t()} | {:error, :not_found}
  def get_by_ref_id(tenant_id, ref_id) do
    case Repo.get_by(Lead, tenant_id: tenant_id, ref_id: ref_id) do
      nil -> {:error, :not_found}
      %Lead{} = lead -> {:ok, lead}
    end
  end

  @spec get_by_id(String.t(), String.t()) ::
          {:ok, Lead.t()} | {:error, :not_found}
  def get_by_id(tenant_id, lead_id) do
    case Repo.get_by(Lead, tenant_id: tenant_id, id: lead_id) do
      nil -> {:error, :not_found}
      %Lead{} = lead -> {:ok, lead}
    end
  end

  @spec list_by_tenant_id(tenant_id :: String.t()) ::
          {:ok, [Lead.t()]} | {:error, :not_found}
  def list_by_tenant_id(tenant_id) do
    leads = from(l in Lead, where: l.tenant_id == ^tenant_id) |> Repo.all()

    case leads do
      [] -> {:error, :not_found}
      leads -> {:ok, leads}
    end
  end

  @spec list_view_by_tenant_id(tenant_id :: String.t()) :: [LeadView.t()]
  def list_view_by_tenant_id(tenant_id) do
    # Subquery to get the most recent document for each ref_id
    latest_doc =
      from rd in "refs_documents",
        group_by: rd.ref_id,
        select: %{
          ref_id: rd.ref_id,
          document_id: max(rd.document_id)
        }

    from(l in Lead,
      where: l.tenant_id == ^tenant_id and l.type == :company,
      join: c in Company,
      on: c.id == l.ref_id,
      left_join: rd in subquery(latest_doc),
      on: rd.ref_id == l.ref_id,
      select: %{
        id: l.id,
        ref_id: l.ref_id,
        type: l.type,
        stage: l.stage,
        name: c.name,
        industry: c.industry,
        domain: c.primary_domain,
        country: c.country_a2,
        icon_key: c.icon_key,
        document_id: rd.document_id
      }
    )
    |> Repo.all()
    |> Enum.map(fn lead_data ->
      # Generate CDN URL for icon if icon_key exists
      icon = Images.get_cdn_url(lead_data.icon_key)

      country_name =
        if lead_data.country do
          case Countriex.get_by(:alpha2, lead_data.country) do
            %{name: name} -> name
            _ -> nil
          end
        else
          nil
        end

      LeadView
      |> struct(
        lead_data
        |> Map.put(:icon, icon)
        |> Map.put(:country_name, country_name)
      )
    end)
  end

  def get_or_create(tenant, attrs) do
    case Tenants.get_tenant_by_name(tenant) do
      {:error, :not_found} ->
        {:error, :not_found, "Tenant not found"}

      {:ok, tenant} ->
        case get_by_ref_id(tenant.id, attrs.ref_id) do
          {:error, :not_found} ->
            %Lead{}
            |> Lead.changeset(%{
              tenant_id: tenant.id,
              ref_id: attrs.ref_id,
              type: attrs.type,
              stage: Map.get(attrs, :stage, :target)
            })
            |> Repo.insert()
            |> tap(fn {:ok, result} ->
              icon_url =
                case Core.Crm.Companies.get_icon_url(result.ref_id) do
                  {:ok, icon_url} -> icon_url
                  _ -> nil
                end

              Web.Endpoint.broadcast("events:#{tenant.id}", "event", %{
                type: :lead_created,
                payload: %{
                  id: result.id,
                  icon_url: icon_url
                }
              })

              result
            end)

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
