defmodule Core.WebTracker.SessionCloser do
  @moduledoc """
  GenServer responsible for periodically closing inactive web sessions.
  """
  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  alias Core.WebTracker.Sessions
  alias Core.Utils.Tracing
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock

  # 2 minutes
  @default_interval_ms 2 * 60 * 1000
  # 15 seconds
  @short_interval_ms 15 * 1000
  @default_batch_size 100
  # Duration in minutes after which a lock is considered stuck
  @stuck_lock_duration_minutes 30

  def start_link(opts \\ []) do
    enabled = Application.get_env(:core, :crons)[:enabled] || false

    if enabled do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      Logger.info("Web session closer is disabled")
      :ignore
    end
  end

  @impl true
  def init(_opts) do
    CronLocks.register_cron(:cron_session_closer)

    schedule_check(@default_interval_ms)

    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_sessions, state) do
    OpenTelemetry.Tracer.with_span "web_session_closer.check_sessions" do
      lock_uuid = Ecto.UUID.generate()

      case CronLocks.acquire_lock(:cron_session_closer, lock_uuid) do
        %CronLock{} ->
          # Lock acquired, proceed with processing
          sessions = Sessions.get_sessions_to_close(@default_batch_size)
          session_count = length(sessions)

          OpenTelemetry.Tracer.set_attributes([
            {"sessions.found", session_count},
            {"batch.size", @default_batch_size}
          ])

          # Close each session and log the result
          results = Enum.map(sessions, &close_session/1)

          # Count successes and failures
          {success_count, failure_count} =
            Enum.reduce(results, {0, 0}, fn
              {:ok, _}, {success, failure} -> {success + 1, failure}
              {:error, _}, {success, failure} -> {success, failure + 1}
            end)

          OpenTelemetry.Tracer.set_attributes([
            {"sessions.closed", success_count},
            {"sessions.failed", failure_count}
          ])

          # Set span status based on results
          if failure_count > 0 do
            Tracing.error("some_sessions_failed_to_close")
          else
            Tracing.ok()
          end

          # Release the lock after processing
          CronLocks.release_lock(:cron_session_closer, lock_uuid)

          # Choose interval based on whether we hit the batch size
          next_interval_ms =
            if session_count == @default_batch_size,
              do: @short_interval_ms,
              else: @default_interval_ms

          schedule_check(next_interval_ms)

        nil ->
          # Lock not acquired, try to force release if stuck
          Logger.info("Session closer lock not acquired, attempting to release any stuck locks")

          case CronLocks.force_release_stuck_lock(:cron_session_closer, @stuck_lock_duration_minutes) do
            :ok ->
              Logger.info("Successfully released stuck lock, will retry acquisition on next run")
            :error ->
              Logger.info("No stuck lock found or could not release it")
          end

          schedule_check(@default_interval_ms)
      end

      {:noreply, state}
    end
  end

  # Schedule the next check
  defp schedule_check(interval_ms) do
    Process.send_after(self(), :check_sessions, interval_ms)
  end

  defp close_session(session) do
    OpenTelemetry.Tracer.with_span "web_session_closer.close_session" do
      OpenTelemetry.Tracer.set_attributes([
        {"session.id", session.id},
        {"session.tenant", session.tenant},
        {"session.visitor_id", session.visitor_id}
      ])

      case Sessions.close(session) do
        {:ok, closed_session} ->
          Tracing.ok()
          Logger.info("Closed web session: #{closed_session.id}")
          {:ok, closed_session}

        {:error, changeset} ->
          Tracing.error(inspect(changeset.errors))

          Logger.error(
            "Failed to close web session: #{session.id}, errors: #{inspect(changeset.errors)}"
          )

          {:error, changeset}
      end
    end
  end
end
