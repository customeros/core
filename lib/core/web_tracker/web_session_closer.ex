defmodule Core.WebTracker.WebSessionCloser do
  @moduledoc """
  GenServer responsible for periodically closing inactive web sessions.
  """
  use GenServer
  require Logger
  alias Core.WebTracker.WebSessions

  @default_interval_ms 2 * 60 * 1000
  @short_interval_ms 5 * 1000
  @default_batch_size 100

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Schedule the first check
    schedule_check(@default_interval_ms)

    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_sessions, state) do
    # Get sessions that need to be closed
    sessions = WebSessions.get_sessions_to_close(@default_batch_size)
    session_count = length(sessions)

    # Close each session and log the result
    Enum.each(sessions, &close_session/1)

    # Choose interval based on whether we hit the batch size
    next_interval_ms = if session_count == @default_batch_size, do: @short_interval_ms, else: @default_interval_ms
    schedule_check(next_interval_ms)

    {:noreply, state}
  end

  # Schedule the next check
  defp schedule_check(interval_ms) do
    Process.send_after(self(), :check_sessions, interval_ms)
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
