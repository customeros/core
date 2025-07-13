defmodule Core.WebTracker.CompanyEnricher do
  @moduledoc """
  Handles company enrichment jobs for web tracker events.

  This module processes web tracker events to enrich company data by:
  1. Extracting domain information from event data
  2. Fetching company information from IP and domain
  3. Creating or updating company records
  4. Associating sessions with companies
  5. Creating leads for new companies
  """

  require Logger
  require OpenTelemetry.Tracer

  alias Core.Crm.Leads
  alias Core.Crm.Companies
  alias Core.Utils.Tracing
  alias Core.WebTracker.Sessions
  alias Core.WebTracker.IPProfiler
  alias Core.WebTracker.IpIdentifier.IpIntelligence

  @doc """
  Enqueues a company enrichment job for an event.

  Starts an asynchronous task to process company enrichment
  without blocking the main event creation flow.
  """
  @spec enqueue(Core.WebTracker.Events.Event.t()) ::
          {:ok, pid()} | {:error, term()}
  def enqueue(event) do
    Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
      enrich_event_company(event)
    end)
  end

  @doc """
  Processes company enrichment for an event.

  Only processes enrichment for events with new sessions to avoid
  duplicate processing for existing sessions.
  """

  def enrich_event_company(event) do
    if event.with_new_session && should_enrich?(event.ip) do
      OpenTelemetry.Tracer.with_span "company_enrichment_job.enrich_event_company" do
        OpenTelemetry.Tracer.set_attributes([
          {"event.id", event.id},
          {"event.session_id", event.session_id},
          {"event.type", event.event_type}
        ])

        enrich(event)
      end
    else
      :ok
    end
  end

  # Private Functions
  def should_enrich?(ip_address) do
    case IpIntelligence.get_by_ip(ip_address) do
      {:ok, nil} ->
        true

      {:ok, record} ->
        record.domain == ""

      _ ->
        true
    end
  end

  defp enrich(event) do
    case IPProfiler.get_company_info(event.ip) do
      {:ok, %{domain: domain}} ->
        process_company_data(event, domain)

      {:error, reason} ->
        Tracing.error(reason, "Failed to get company info",
          session_id: event.session_id,
          ip: event.ip
        )
    end
  end

  defp process_company_data(event, domain) do
    OpenTelemetry.Tracer.with_span "company_enrichment_job.process_company_data" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.domain", domain},
        {"param.session_id", event.session_id},
        {"param.tenant.id", event.tenant_id}
      ])

      with {:ok, db_company} <- Companies.get_or_create_by_domain(domain),
           {:ok, _session} <-
             Sessions.set_company_id(event.session_id, db_company.id),
           {:ok, _lead} <-
             Leads.get_or_create(event.tenant_id, %{
               type: :company,
               ref_id: db_company.id
             }) do
        Tracing.ok()
        :ok
      else
        {:error, :no_primary_domain} ->
          Tracing.warning(
            :no_primary_domain,
            "No primary domain found for #{domain}",
            domain: domain
          )

        {:error, :domain_not_reachable} ->
          Tracing.warning(
            :domain_not_reachable,
            "Domain not reachable: #{domain}",
            company_domain: domain
          )

        {:error, :cannot_resolve_to_primary_domain} ->
          Tracing.warning(
            :cannot_resolve_to_primary_domain,
            "Cannot resolve to primary domain: #{domain}",
            company_domain: domain
          )

        {:error, :cannot_resolve_url} ->
          Tracing.warning(
            :cannot_resolve_url,
            "Cannot resolve url: #{domain}",
            company_domain: domain
          )

        {:error, reason} ->
          Tracing.error(reason, "Company not created from webTracker",
            company_domain: domain,
            session_id: event.session_id
          )
      end
    end
  end
end
