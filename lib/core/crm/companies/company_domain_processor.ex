defmodule Core.Crm.Companies.CompanyDomainProcessor do
  @moduledoc """
  GenServer responsible for periodically processing company domains from the queue.
  Creates new companies for unprocessed domains.

  Configuration:
  - Uses general cron configuration from :core, :crons, :enabled
  """
  use GenServer
  require Logger
  require OpenTelemetry.Tracer

  alias Core.Crm.Companies
  alias Core.Crm.Companies.CompanyDomainQueue
  alias Core.Repo
  alias Core.Utils.DomainExtractor
  alias Core.Utils.Tracing
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock
  import Ecto.Query

  # 1 minute
  @default_interval_ms 1 * 60 * 1000
  # 15 minutes
  @long_interval_ms 15 * 60 * 1000
  @default_batch_size 5
  # Duration in minutes after which a lock is considered stuck
  @stuck_lock_duration_minutes 30

  def start_link(opts \\ []) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      Logger.info("Company domain processor is disabled (crons disabled)")
      :ignore
    end
  end

  @impl true
  def init(_opts) do
    CronLocks.register_cron(:cron_company_domain_processor)
    # Schedule the first check
    schedule_check(@default_interval_ms)

    {:ok, %{}}
  end

  @impl true
  def handle_info(:process_domains, state) do
    OpenTelemetry.Tracer.with_span "company_domain_processor.process_domains" do
      lock_uuid = Ecto.UUID.generate()

      case CronLocks.acquire_lock(:cron_company_domain_processor, lock_uuid) do
        %CronLock{} ->
          # Lock acquired, proceed with processing
          domains = fetch_unprocessed_domains(@default_batch_size)
          domain_count = length(domains)

          OpenTelemetry.Tracer.set_attributes([
            {"domains.found", domain_count},
            {"batch.size", @default_batch_size}
          ])

          # Process each domain
          Enum.each(domains, &process_domain/1)

          # Release the lock after processing
          CronLocks.release_lock(:cron_company_domain_processor, lock_uuid)

          # Choose interval based on whether we found any domains
          next_interval_ms =
            if domain_count > 0,
              do: @default_interval_ms,
              else: @long_interval_ms

          schedule_check(next_interval_ms)

        nil ->
          # Lock not acquired, try to force release if stuck
          Logger.info(
            "Company domain processor lock not acquired, attempting to release any stuck locks"
          )

          case CronLocks.force_release_stuck_lock(
                 :cron_company_domain_processor,
                 @stuck_lock_duration_minutes
               ) do
            :ok ->
              Logger.info(
                "Successfully released stuck lock, will retry acquisition on next run"
              )

            :error ->
              Logger.info("No stuck lock found or could not release it")
          end

          schedule_check(@default_interval_ms)
      end

      {:noreply, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("CompanyDomainProcessor received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Schedule the next check
  defp schedule_check(interval_ms) do
    Process.send_after(self(), :process_domains, interval_ms)
  end

  defp fetch_unprocessed_domains(batch_size) do
    from(q in CompanyDomainQueue,
      where: is_nil(q.processed_at),
      limit: ^batch_size,
      select: q
    )
    |> Repo.all()
  end

  defp process_domain(queue_item) do
    OpenTelemetry.Tracer.with_span "company_domain_processor.process_domain" do
      OpenTelemetry.Tracer.set_attributes([
        {"queue_item.id", queue_item.id},
        {"queue_item.domain", queue_item.domain}
      ])

      # Extract base domain from the original domain
      case DomainExtractor.extract_base_domain(queue_item.domain) do
        {:ok, base_domain} ->
          OpenTelemetry.Tracer.set_attributes([
            {"base_domain", base_domain}
          ])

          case Companies.get_or_create_by_domain(base_domain) do
            {:ok, company} ->
              Tracing.ok()

              OpenTelemetry.Tracer.set_attributes([
                {"company.id", company.id},
                {"company.domain", company.primary_domain}
              ])

              mark_as_processed(queue_item.id)

            {:error, reason} ->
              Tracing.error(reason)

              Logger.warning(
                "Rejected domain #{queue_item.domain} (base domain: #{base_domain}), reason: #{inspect(reason)}"
              )

              mark_as_processed(queue_item.id)
          end

        {:error, reason} ->
          Tracing.error(reason, "Failed to extract base domain",
            company_domain: queue_item.domain
          )

          mark_as_processed(queue_item.id)
      end
    end
  end

  defp mark_as_processed(id) do
    from(q in CompanyDomainQueue,
      where: q.id == ^id,
      update: [set: [processed_at: fragment("NOW()")]]
    )
    |> Repo.update_all([])
  end
end
