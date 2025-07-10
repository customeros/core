defmodule Core.Analytics.Builder do
  import Ecto.Query
  require Logger

  alias Core.Repo
  alias Core.Crm.Leads.Lead
  alias Core.Auth.Tenants.Tenant
  alias Core.Analytics.LeadGeneration
  alias Core.WebTracker.Sessions.Session

  @err_unable_to_compute {:error, "unable to compute stats"}

  def build_hourly_aggregate_stats(tenant_id, start_time_utc) do
    end_time_utc = DateTime.add(start_time_utc, 1, :hour)
    build_aggregate_stats(tenant_id, start_time_utc, end_time_utc)
  end

  defp build_aggregate_stats(tenant_id, start_time_utc, end_time_utc) do
    with {:ok, sessions} <-
           get_sessions(tenant_id, start_time_utc, end_time_utc),
         {:ok, icp_sessions} <-
           get_icp_qualified_sessions(tenant_id, start_time_utc, end_time_utc),
         {:ok, companies} <-
           get_unique_companies(tenant_id, start_time_utc, end_time_utc),
         {:ok, new_companies} <-
           get_unique_new_companies(tenant_id, start_time_utc, end_time_utc),
         {:ok, new_leads} <-
           get_new_icp_fit_leads(tenant_id, start_time_utc, end_time_utc) do
      LeadGeneration.create(%{
        bucket_start_at: start_time_utc,
        tenant_id: tenant_id,
        sessions: sessions.sessions,
        identified_sessions: sessions.identified_sessions,
        icp_fit_sessions: icp_sessions.icp_qualified_sessions,
        unique_companies: companies.unique_companies,
        unique_new_companies: new_companies.unique_new_companies,
        new_icp_fit_leads: new_leads.new_icp_fit_leads
      })
    else
      error ->
        Logger.error("unable to compute aggregate stats for #{tenant_id}", %{
          tenant_id: tenant_id,
          start_time_utc: start_time_utc,
          end_time_utc: end_time_utc,
          error: inspect(error)
        })

        @err_unable_to_compute
    end
  end

  @doc """
  Gets sessions and identified sessions for a tenant.
  Returns :not_found or {:ok, %{sessions: count, identified_sessions: count}}
  """
  def get_sessions(tenant_id, start_time_utc, end_time_utc) do
    results =
      from(ws in Session,
        join: t in Tenant,
        on: ws.tenant == t.name,
        where:
          t.id == ^tenant_id and
            ws.started_at >= ^start_time_utc and
            ws.started_at < ^end_time_utc and
            ws.active == false,
        select: %{
          sessions: count(ws.id),
          identified_sessions: filter(count(ws.id), not is_nil(ws.company_id))
        }
      )
      |> Repo.one()

    case results do
      nil -> :not_found
      _ -> {:ok, results}
    end
  end

  @doc """
  Gets sessions with icp qualified companies for a tenant.
  Returns :not_found or {:ok, %{icp_qualified_sessions: count}}
  """

  def get_icp_qualified_sessions(tenant_id, start_time_utc, end_time_utc) do
    results =
      from(ws in Session,
        join: t in Tenant,
        on: ws.tenant == t.name,
        join: l in Lead,
        on: l.tenant_id == t.id and l.ref_id == ws.company_id,
        where:
          t.id == ^tenant_id and
            ws.started_at >= ^start_time_utc and
            ws.started_at < ^end_time_utc and
            ws.active == false and
            not is_nil(ws.company_id) and
            l.icp_fit in [:strong, :moderate],
        select: %{
          icp_qualified_sessions: count(ws.id)
        }
      )
      |> Repo.one()

    case results do
      nil -> :not_found
      _ -> {:ok, results}
    end
  end

  @doc """
  Gets sessions with icp qualified companies for a tenant.
  Returns :not_found or {:ok, %{icp_qualified_sessions: count}}
  """
  def get_unique_companies(tenant_id, start_time_utc, end_time_utc) do
    results =
      from(ws in Session,
        join: t in Tenant,
        on: ws.tenant == t.name,
        where:
          t.id == ^tenant_id and
            ws.started_at >= ^start_time_utc and
            ws.started_at < ^end_time_utc and
            ws.active == false and
            not is_nil(ws.company_id),
        select: %{
          unique_companies: count(ws.company_id, :distinct)
        }
      )
      |> Repo.one()

    case results do
      nil -> :not_found
      _ -> {:ok, results}
    end
  end

  def get_unique_new_companies(tenant_id, start_time_utc, end_time_utc) do
    existing_companies_query =
      from(l in Lead,
        where:
          l.tenant_id == ^tenant_id and
            l.inserted_at < ^start_time_utc and
            not is_nil(l.ref_id),
        select: l.ref_id,
        distinct: true
      )

    results =
      from(ws in Session,
        join: t in Tenant,
        on: ws.tenant == t.name,
        where:
          t.id == ^tenant_id and
            ws.started_at >= ^start_time_utc and
            ws.started_at < ^end_time_utc and
            ws.active == false and
            not is_nil(ws.company_id) and
            ws.company_id not in subquery(existing_companies_query),
        select: %{
          unique_new_companies: count(ws.company_id, :distinct)
        }
      )
      |> Repo.one()

    case results do
      nil -> {:ok, %{unique_new_companies: 0}}
      _ -> {:ok, results}
    end
  end

  @doc """
  Gets new icp_fit leads created during a time period for a company
  Returns :not_found or {:ok, %{new_icp_fit_leads: count}}
  """
  def get_new_icp_fit_leads(tenant_id, start_time_utc, end_time_utc) do
    results =
      from(l in Lead,
        join: t in Tenant,
        on: l.tenant_id == t.id,
        where:
          t.id == ^tenant_id and
            l.inserted_at >= ^start_time_utc and
            l.inserted_at < ^end_time_utc and
            l.icp_fit in [:strong, :moderate] and
            l.stage in [:education, :solution, :evaluation, :ready_to_buy],
        select: %{
          new_icp_fit_leads: count(l.id)
        }
      )
      |> Repo.one()

    case results do
      nil -> :not_found
      _ -> {:ok, results}
    end
  end
end
