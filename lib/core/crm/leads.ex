defmodule Core.Crm.Leads do
  @moduledoc """
  The Leads context.
  """

  import Ecto.Query, warn: false
  require OpenTelemetry.Tracer
  require Logger
  alias Ecto.Repo
  alias Core.Repo
  alias Core.Crm.Leads.{Lead, LeadView}
  alias Core.Auth.Tenants
  alias Core.Crm.Companies.Company
  alias Core.Utils.Media.Images
  alias Core.Utils.Tracing

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
    OpenTelemetry.Tracer.with_span "core.crm.leads:list_view_by_tenant_id" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.id", tenant_id}
      ])

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
  end

  @spec get_or_create(tenant :: String.t(), attrs :: map()) ::
          {:ok, Lead.t()} | {:error, :not_found}
  def get_or_create(tenant, attrs) do
    case Tenants.get_tenant_by_name(tenant) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, tenant} ->
        case get_by_ref_id(tenant.id, attrs.ref_id) do
          {:error, :not_found} ->
            %Lead{}
            |> Lead.changeset(%{
              tenant_id: tenant.id,
              ref_id: attrs.ref_id,
              type: attrs.type,
              stage: Map.get(attrs, :stage, :pending)
            })
            |> Repo.insert()
            |> tap(fn {:ok, result} -> after_insert_start(result) end)

          lead ->
            {:ok, lead}
        end
    end
  end

  defp after_insert_start(result) do
    Task.start(fn ->
      icon_url =
        case Core.Crm.Companies.get_icon_url(result.ref_id) do
          {:ok, icon_url} -> icon_url
          _ -> nil
        end

      Web.Endpoint.broadcast("events:#{result.tenant_id}", "event", %{
        type: :lead_created,
        payload: %{
          id: result.id,
          icon_url: icon_url
        }
      })
    end)

    Core.Researcher.NewLeadPipeline.start(result.id, result.tenant_id)
  end

  def update_lead(%Lead{} = lead, attrs) do
    lead
    |> Lead.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks an attempt for a lead by updating the attempt timestamp and incrementing the attempts counter.
  Returns :ok on success or {:error, :update_failed} if the update fails.
  """
  def mark_icp_fit_attempt(lead_id) do
    case Repo.update_all(
           from(l in Lead, where: l.id == ^lead_id),
           set: [icp_fit_evaluation_attempt_at: DateTime.utc_now()],
           inc: [icp_fit_evaluation_attempts: 1]
         ) do
      {0, _} ->
        Tracing.error(:update_failed)
        Logger.error("Failed to mark attempt for lead #{lead_id}")
        {:error, :update_failed}

      {_count, _} ->
        :ok
    end
  end
end
