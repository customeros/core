defmodule Core.WebTracker.Events.IdentifyEventHandler do
  @moduledoc """
  Handles identify events from web tracking to associate users with companies.

  This module processes identify events that contain email information, extracts
  company domains, and manages the association between sessions, companies, and leads.
  Key responsibilities include:

  - Extracting and validating email domains from identify events
  - Filtering out personal email providers
  - Managing company associations in sessions
  - Creating or updating company and lead records
  - Tracking IP intelligence data for domains

  The handler runs asynchronously using Task.Supervisor to avoid blocking the
  event processing pipeline.
  """

  require Logger
  require OpenTelemetry.Tracer

  alias Core.Crm.Leads
  alias Core.Utils.Tracing
  alias Core.Crm.Companies
  alias Core.WebTracker.Sessions
  alias Core.Utils.DomainExtractor
  alias Core.Utils.PrimaryDomainFinder
  alias Core.Auth.PersonalEmailProviders
  alias Core.WebTracker.IpIdentifier.IpIntelligence

  def handle(event) do
    Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
      process_identify_event(event)
    end)
  end

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
          Logger.error(
            "IpIntelligence upsert failed for #{ip_address}, #{domain}: #{reason}"
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

  defp process_identify_domain(event, domain) do
    OpenTelemetry.Tracer.with_span "company_enrichment_job.process_identify_domain" do
      OpenTelemetry.Tracer.set_attributes([
        {"extracted.domain", domain},
        {"event.session_id", event.session_id}
      ])

      with {:ok, session} <- Sessions.get_session_by_id(event.session_id),
           true <- reassociation_needed?(session, domain),
           :ok <- reassociate_company(event, domain) do
        Tracing.ok()
        :ok
      else
        {:error, reason} ->
          Tracing.error(reason, "Failed to process identify domain",
            session_id: event.session_id,
            domain: domain
          )

          {:error, reason}

        false ->
          Tracing.ok()
          :ok
      end
    end
  end

  defp reassociation_needed?(session, domain) do
    case session.company_id do
      nil ->
        true

      _ ->
        !event_domain_match_session_company?(session.company_id, domain)
    end
  end

  defp event_domain_match_session_company?(company_id, event_domain) do
    case Companies.get_by_id(company_id) do
      {:ok, company} ->
        company.primary_domain == event_domain

      _ ->
        false
    end
  end

  defp reassociate_company(event, domain) do
    with {:ok, db_company} <- Companies.get_or_create_by_domain(domain),
         {:ok, _session} <-
           Sessions.set_company_id(event.session_id, db_company.id),
         {:ok, _lead} <-
           Leads.get_or_create(event.tenant_id, %{
             type: :company,
             ref_id: db_company.id
           }) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to reassociate company: #{reason}",
          session_id: event.session_id,
          domain: domain
        )

        {:error, reason}
    end
  end
end
