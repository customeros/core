defmodule Core.WebTracker.CompanyEnrichmentJob do
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
  alias Core.Utils.DomainExtractor
  alias Core.Utils.PrimaryDomainFinder
  alias Core.Auth.PersonalEmailProviders
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
  Enqueues a company enrichment job for an identify event with existing session.

  This handles the special case where an identify event occurs on an existing session
  and we need to check if the domain from the email matches the current session's company.
  """
  @spec enqueue_identify_event(Core.WebTracker.Events.Event.t()) ::
          {:ok, pid()} | {:error, term()}
  def enqueue_identify_event(event) do
    Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
      process_identify_event(event)
    end)
  end

  @doc """
  Processes company enrichment for an event.

  Only processes enrichment for events with new sessions to avoid
  duplicate processing for existing sessions.
  """
  @spec enrich_event_company(Core.WebTracker.Events.Event.t()) :: :ok
  def enrich_event_company(event) do
    if event.with_new_session do
      OpenTelemetry.Tracer.with_span "company_enrichment_job.enrich_event_company" do
        OpenTelemetry.Tracer.set_attributes([
          {"event.id", event.id},
          {"event.session_id", event.session_id},
          {"event.type", event.event_type}
        ])

        do_enrichment(event)
      end
    else
      :ok
    end
  end

  @doc """
  Processes identify event for existing session.

  Checks if the domain from the email matches the current session's company.
  If not, creates a new company/lead and reassociates the session.
  """
  @spec process_identify_event(Core.WebTracker.Events.Event.t()) :: :ok
  def process_identify_event(event) do
    OpenTelemetry.Tracer.with_span "company_enrichment_job.process_identify_event" do
      OpenTelemetry.Tracer.set_attributes([
        {"event.id", event.id},
        {"event.session_id", event.session_id},
        {"event.type", event.event_type}
      ])

      case extract_domain_from_event(event) do
        nil ->
          # No valid domain extracted, skip processing
          :ok

        domain ->
          process_identify_domain(event, domain)
      end
    end
  end

  defp process_identify_domain(event, domain) do
    OpenTelemetry.Tracer.with_span "company_enrichment_job.process_identify_domain" do
      OpenTelemetry.Tracer.set_attributes([
        {"extracted.domain", domain},
        {"event.session_id", event.session_id}
      ])

      with {:ok, session} <- Sessions.get_session_by_id(event.session_id),
           {:ok, should_reassociate} <-
             check_if_reassociation_needed(session, domain),
           {:ok, _} <-
             maybe_reassociate_company(event, domain, should_reassociate) do
        Tracing.ok()
        :ok
      else
        {:error, reason} ->
          Tracing.error(reason, "Failed to process identify domain",
            session_id: event.session_id,
            domain: domain
          )

          {:error, reason}
      end
    end
  end

  defp check_if_reassociation_needed(session, domain) do
    case session.company_id do
      nil ->
        # No company associated, need to reassociate
        {:ok, true}

      company_id ->
        # Check if current company's primary domain matches extracted domain
        case Companies.get_by_id(company_id) do
          {:ok, company} ->
            should_reassociate = company.primary_domain != domain
            {:ok, should_reassociate}

          {:error, :not_found} ->
            # Company not found, need to reassociate
            {:ok, true}
        end
    end
  end

  @doc false
  defp maybe_reassociate_company(event, domain, true) do
    # Reassociation needed - create/get company and update session
    with {:ok, db_company} <- Companies.get_or_create_by_domain(domain),
         {:ok, _session} <-
           Sessions.set_company_id(event.session_id, db_company.id),
         {:ok, _lead} <-
           Leads.get_or_create(event.tenant_id, %{
             type: :company,
             ref_id: db_company.id
           }) do
      Tracing.ok()
      {:ok, :reassociated}
    else
      {:error, reason} ->
        Tracing.error(reason, "Failed to reassociate company",
          session_id: event.session_id,
          domain: domain
        )

        {:error, reason}
    end
  end

  defp maybe_reassociate_company(_event, _domain, false) do
    # No reassociation needed
    {:ok, :no_change}
  end

  # Private Functions

  defp do_enrichment(event) do
    default_domain = extract_domain_from_event(event)

    case IPProfiler.get_company_info(event.ip, default_domain) do
      {:ok, %{domain: domain, company: _company}} ->
        process_company_data(event, domain)

      {:error, reason} ->
        Tracing.error(reason, "Failed to get company info",
          session_id: event.session_id,
          ip: event.ip
        )
    end
  end

  defp extract_domain_from_event(%{
         ip: ip_address,
         event_type: "identify",
         event_data: event_data
       }) do
    with {:ok, email} <- extract_email_from_event(event_data),
         {:ok, domain} <- process_email_from_event(email) do
      case IpIntelligence.upsert(%{
             ip: ip_address,
             domain_source: :tracker,
             domain: domain
           }) do
        {:error, reason} ->
          Tracing.error(
            reason,
            "IpIntelligence upsert failed for #{ip_address}, #{domain}"
          )

        _ ->
          :ok
      end

      domain
    else
      _ ->
        nil
    end
  end

  defp extract_domain_from_event(_), do: nil

  defp extract_email_from_event(event_data) do
    case Jason.decode(event_data) do
      {:ok, %{"email" => email}} -> {:ok, email}
      _ -> nil
    end
  end

  defp process_email_from_event(email) do
    with {:ok, domain} <- DomainExtractor.extract_domain_from_email(email),
         false <- PersonalEmailProviders.exists_by_domain?(domain),
         {:ok, primary_domain} <-
           PrimaryDomainFinder.get_primary_domain(domain) do
      {:ok, primary_domain}
    else
      _ ->
        nil
    end
  end

  @doc false
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
