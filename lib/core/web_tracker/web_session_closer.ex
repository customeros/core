defmodule Core.WebTracker.WebSessionCloser do
  @moduledoc """
  GenServer responsible for periodically closing inactive web sessions.
  """
  use GenServer
  require Logger
  alias Core.WebTracker.WebSessions

  # Default interval is 2 minutes
  @default_interval_ms 2 * 60 * 1000
  # Process 100 sessions at a time by default
  @default_batch_size 100

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval_ms = Keyword.get(opts, :interval_ms, @default_interval_ms)
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    # Schedule the first check
    schedule_check(interval_ms)

    {:ok, %{interval_ms: interval_ms, batch_size: batch_size}}
  end

  @impl true
  def handle_info(:check_sessions, %{interval_ms: interval_ms, batch_size: batch_size} = state) do
    close_inactive_sessions(batch_size)
    schedule_check(interval_ms)
    {:noreply, state}
  end

  # Schedule the next check
  defp schedule_check(interval_ms) do
    Process.send_after(self(), :check_sessions, interval_ms)
  end

  # Close inactive sessions
  defp close_inactive_sessions(batch_size) do
    # Get sessions that need to be closed
    sessions = WebSessions.get_sessions_to_close(batch_size)

    # Close each session and log the result
    Enum.each(sessions, &close_session/1)
  end

  defp close_session(session) do
    case WebSessions.close(session) do
      {:ok, closed_session} ->
        Logger.info("Closed web session: #{closed_session.id}")

      {:error, changeset} ->
        Logger.error("Failed to close web session: #{session.id}, errors: #{inspect(changeset.errors)}")
    end
  end
end
