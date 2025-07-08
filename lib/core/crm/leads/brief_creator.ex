defmodule Core.Crm.Leads.BriefCreator do
  @moduledoc """
  Job responsible for creating briefs for leads.

  This module:
  * Monitors leads that need brief creation
  """

  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query
  alias Core.Crm.Leads
  alias Core.Crm.Leads.Lead
  alias Core.Crm.Documents
  alias Core.Crm.Companies
  alias Core.Researcher.BriefWriter
  alias Core.Repo
  alias Core.Utils.Tracing
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock

  @default_interval 5 * 60 * 1000
  @default_batch_size 10
  @stuck_lock_duration_minutes 30
  @max_attempts 3
  @delay_between_checks_hours 4
  @delay_from_lead_creation_minutes 30

  @doc """
  Starts the stage evaluator process.
  """
  def start_link(_opts) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    else
      Logger.info("Brief creator is disabled (crons disabled)")
      :ignore
    end
  end

  # Server Callbacks

  @impl true
  def init(_) do
    CronLocks.register_cron(:cron_brief_creator)
    schedule_initial_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_leads, state) do
    OpenTelemetry.Tracer.with_span "brief_creator.check_leads" do
      lock_uuid = Ecto.UUID.generate()

      case CronLocks.acquire_lock(:cron_brief_creator, lock_uuid) do
        %CronLock{} ->
          case fetch_leads_without_briefs() do
            {:ok, leads} ->
              OpenTelemetry.Tracer.set_attributes([
                {"leads.count", length(leads)}
              ])

              Enum.each(leads, fn lead ->
                process_lead(lead)
              end)

            {:error, :not_found} ->
              OpenTelemetry.Tracer.set_attributes([
                {"leads.count", 0}
              ])

              Logger.info("No leads found for brief creation")
          end

          CronLocks.release_lock(:cron_brief_creator, lock_uuid)

        nil ->
          # Lock not acquired, try to force release if stuck
          Logger.info(
            "Brief creator lock not acquired, attempting to release any stuck locks"
          )

          case CronLocks.force_release_stuck_lock(
                 :cron_brief_creator,
                 @stuck_lock_duration_minutes
               ) do
            :ok ->
              Logger.info(
                "Successfully released stuck lock, will retry acquisition on next run"
              )

            :error ->
              Logger.info("No stuck lock found or could not release it")
          end
      end

      schedule_next_check()
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("BriefCreator received unexpected message: #{inspect(msg)}")

    {:noreply, state}
  end

  # Private Functions
  defp process_lead(%Lead{} = lead) do
    OpenTelemetry.Tracer.with_span "brief_creator.process_lead" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.lead.id", lead.id},
        {"param.tenant.id", lead.tenant_id}
      ])

      Logger.info(
        "Processing lead, lead_id: #{lead.id}, attempt: #{lead.brief_create_attempts + 1}"
      )

      case Leads.mark_brief_create_attempt(lead.id) do
        :ok -> handle_lead_processing(lead)
        {:error, :update_failed} -> handle_update_failure(lead)
      end
    end
  end

  defp handle_lead_processing(lead) do
    case Documents.get_documents_by_ref_id(lead.id) do
      [] -> create_brief_for_lead(lead)
      documents -> check_for_account_brief(lead, documents)
    end
  end

  defp handle_update_failure(lead) do
    Tracing.error(
      :update_failed,
      "Failed to mark brief creation attempt for lead: #{lead.id}",
      lead_id: lead.id
    )
  end

  defp create_brief_for_lead(%Lead{} = lead) do
    OpenTelemetry.Tracer.with_span "brief_creator.create_brief_for_lead" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.lead.id", lead.id}
      ])

      case get_company_domain(lead.ref_id) do
        nil -> :ok
        domain -> create_brief_document(lead, domain)
      end
    end
  end

  defp get_company_domain(company_id) do
    case Companies.get_by_id(company_id) do
      {:ok, company} ->
        Logger.info("Company found: #{company.primary_domain}")
        company.primary_domain

      {:error, reason} ->
        Tracing.error(reason, "Company not found", company_id: company_id)
        nil
    end
  end

  defp create_brief_document(%Lead{} = lead, domain) do
    OpenTelemetry.Tracer.with_span "brief_creator.create_brief_document" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.lead.id", lead.id},
        {"param.company.domain", domain}
      ])

      case BriefWriter.create_brief(lead.tenant_id, lead.id, domain) do
        {:ok, _document} ->
          Tracing.ok()
          Logger.info("Document created for lead #{lead.id}")

        {:error, :closed_sessions_not_found} ->
          Tracing.warning(
            :closed_sessions_not_found,
            "Closed sessions not found",
            lead_id: lead.id,
            url: domain,
            tenant_id: lead.tenant_id
          )

        {:error, reason} ->
          Tracing.error(reason, "Document creation failed",
            lead_id: lead.id,
            url: domain,
            tenant_id: lead.tenant_id
          )
      end
    end
  end

  defp check_for_account_brief(lead, documents) do
    case Enum.find(documents, fn doc -> doc.name == "Account Brief" end) do
      nil ->
        Logger.info(
          "Found #{length(documents)} existing document(s) for lead #{lead.id}, but no Account Brief"
        )

        Logger.info("Creating Account Brief as it doesn't exist")
        create_brief_for_lead(lead)

      _account_brief ->
        Logger.info(
          "Found #{length(documents)} existing document(s) for lead #{lead.id}, including Account Brief"
        )

        Logger.info("Skipping brief creation as Account Brief already exists")
    end
  end

  defp schedule_initial_check do
    Process.send_after(self(), :check_leads, @default_interval)
  end

  defp schedule_next_check do
    Process.send_after(self(), :check_leads, @default_interval)
  end

  defp fetch_leads_without_briefs() do
    last_check_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@delay_between_checks_hours, :hour)

    created_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@delay_from_lead_creation_minutes, :minute)

    Lead
    |> where([l], l.inserted_at < ^created_cutoff)
    |> where([l], l.stage not in [:pending, :customer])
    |> where([l], not is_nil(l.stage))
    |> where([l], l.icp_fit in [:strong, :moderate])
    |> where([l], l.brief_create_attempts < ^@max_attempts)
    |> where(
      [l],
      is_nil(l.brief_create_attempt_at) or
        l.brief_create_attempt_at < ^last_check_cutoff
    )
    |> join(:left, [l], rd in "refs_documents", on: rd.ref_id == l.id)
    |> where([l, rd], is_nil(rd.ref_id))
    |> order_by([l], asc_nulls_first: l.brief_create_attempt_at)
    |> limit(^@default_batch_size)
    |> Repo.all()
    |> then(fn
      [] -> {:error, :not_found}
      leads -> {:ok, leads}
    end)
  end
end
