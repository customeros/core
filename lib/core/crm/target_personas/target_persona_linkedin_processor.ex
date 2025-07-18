defmodule Core.Crm.TargetPersonas.TargetPersonaLinkedinProcessor do
  @moduledoc """
  Job responsible for processing target persona LinkedIn queue records.
  """
  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query
  alias Core.Crm.TargetPersonas
  alias Core.Crm.TargetPersonas.TargetPersonaLinkedinQueue
  alias Core.Crm.TargetPersonas.TargetPersonaLinkedinQueues
  alias Core.Repo
  alias Core.Utils.Tracing
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock

  @default_interval 2 * 60 * 1000
  @batch_size 10
  @stuck_lock_duration_minutes 30
  @max_retries 5
  @delay_between_checks_hours 24

  @linkedin_url_prefix "https://linkedin.com/in/"

  @doc """
  Starts the target persona LinkedIn processor process.
  """
  def start_link(_opts) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    else
      Logger.info(
        "Target persona LinkedIn processor is disabled (crons disabled)"
      )

      :ignore
    end
  end

  # Server Callbacks

  @impl true
  def init(_) do
    CronLocks.register_cron(:cron_target_persona_linkedin_processor)
    schedule_initial_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_target_persona_linkedin_queues, state) do
    OpenTelemetry.Tracer.with_span "target_persona_linkedin_processor.check_queues" do
      lock_uuid = Ecto.UUID.generate()

      case CronLocks.acquire_lock(
             :cron_target_persona_linkedin_processor,
             lock_uuid
           ) do
        %CronLock{} ->
          case fetch_target_persona_linkedin_queues_to_process() do
            {:ok, queue_records} ->
              OpenTelemetry.Tracer.set_attributes([
                {"queue_records.count", length(queue_records)}
              ])

              process_queue_records(queue_records)

            {:error, :not_found} ->
              OpenTelemetry.Tracer.set_attributes([
                {"queue_records.count", 0}
              ])

              Logger.debug(
                "No target persona LinkedIn queue records found for processing"
              )
          end

          CronLocks.release_lock(
            :cron_target_persona_linkedin_processor,
            lock_uuid
          )

        nil ->
          Logger.info(
            "Target persona LinkedIn processor lock not acquired, attempting to release any stuck locks"
          )

          case CronLocks.force_release_stuck_lock(
                 :cron_target_persona_linkedin_processor,
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
    Logger.warning(
      "TargetPersonaLinkedinProcessor received unexpected message: #{inspect(msg)}"
    )

    {:noreply, state}
  end

  # Private Functions

  defp format_linkedin_url(url) when is_binary(url) do
    url = String.trim(url)

    cond do
      String.starts_with?(url, [
        "http://linkedin.com/in/",
        "https://linkedin.com/in/",
        "http://www.linkedin.com/in/",
        "https://www.linkedin.com/in/"
      ]) ->
        {:ok, url}

      # If it's just an alias (e.g. "john-doe-123abc")
      String.match?(url, ~r/^[a-zA-Z0-9\-]+$/) ->
        {:ok, @linkedin_url_prefix <> url}

      true ->
        {:error, :invalid_linkedin_url}
    end
  end

  defp format_linkedin_url(_), do: {:error, :invalid_linkedin_url}

  defp process_queue_record(%TargetPersonaLinkedinQueue{} = queue_record) do
    OpenTelemetry.Tracer.with_span "target_persona_linkedin_processor.process_record" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.linkedin_url", queue_record.linkedin_url},
        {"param.tenant_id", queue_record.tenant_id},
        {"param.attempts", queue_record.attempts}
      ])

      case TargetPersonaLinkedinQueues.update_attempt(queue_record.id) do
        {:ok, _updated_record} ->
          with {:ok, formatted_url} <-
                 format_linkedin_url(queue_record.linkedin_url),
               {:ok, _personas} <-
                 TargetPersonas.create_from_linkedin(
                   queue_record.tenant_id,
                   formatted_url
                 ) do
            case TargetPersonaLinkedinQueues.mark_completed(queue_record.id) do
              {:ok, _completed_record} ->
                {:ok, :completed}

              {:error, reason} ->
                Tracing.error(reason, "Failed to mark record as completed",
                  id: queue_record.id
                )

                {:error, :mark_completed_failed}
            end
          else
            {:error, :invalid_linkedin_url} ->
              Tracing.error(
                :invalid_linkedin_url,
                "Invalid LinkedIn URL format",
                id: queue_record.id,
                url: queue_record.linkedin_url
              )

              {:error, :invalid_linkedin_url}

            {:error, reason} ->
              Tracing.error(
                reason,
                "Failed to process target persona LinkedIn record",
                id: queue_record.id,
                linkedin_url: queue_record.linkedin_url
              )

              {:error, reason}
          end

        {:error, reason} ->
          Logger.error("Failed to update attempt for queue record",
            id: queue_record.id,
            reason: reason
          )

          {:error, :update_attempt_failed}
      end
    end
  end

  defp process_queue_records(queue_records) do
    Enum.each(queue_records, &process_queue_record/1)
  end

  defp schedule_initial_check do
    Process.send_after(
      self(),
      :check_target_persona_linkedin_queues,
      @default_interval
    )
  end

  defp schedule_next_check do
    Process.send_after(
      self(),
      :check_target_persona_linkedin_queues,
      @default_interval
    )
  end

  defp fetch_target_persona_linkedin_queues_to_process() do
    last_check_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@delay_between_checks_hours, :hour)

    TargetPersonaLinkedinQueue
    |> where([q], is_nil(q.completed_at))
    |> where([q], q.attempts < ^@max_retries)
    |> where(
      [q],
      is_nil(q.last_attempt_at) or q.last_attempt_at < ^last_check_cutoff
    )
    |> order_by([q], asc_nulls_first: q.last_attempt_at)
    |> limit(^@batch_size)
    |> Repo.all()
    |> case do
      [] ->
        {:error, :not_found}

      records ->
        {:ok, records}
    end
  end
end
