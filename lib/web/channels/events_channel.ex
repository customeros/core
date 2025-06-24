defmodule Web.Channels.EventsChannel do
  @moduledoc """
  Phoenix Channel for managing real-time event broadcasting.

  This channel handles:
  * Real-time event broadcasting within a tenant
  * Tenant-specific event channels
  * Event message handling and distribution
  * Channel lifecycle management

  It provides a simple pub/sub mechanism for broadcasting events
  to all connected clients within a tenant's context.
  """

  use Web, :channel
  require Logger

  @impl true
  def join("events:" <> tenant_id, _payload, socket) do
    Logger.info("joined events channel :: #{tenant_id}")
    {:ok, socket}
  end

  @impl true
  def join(_, _, _) do
    {:ok, self()}
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_in(
        "event",
        %{"event" => %{"user_id" => user_id, "type" => type}},
        socket
      ) do
    # Save the event in the DB
    Core.Stats.register_event_start(user_id, String.to_atom(type))
    broadcast!(socket, "event", %{event: %{user_id: user_id, type: type}})
    {:reply, :ok, socket}
  end

  @impl true
  def terminate(_, socket) do
    {:ok, socket}
  end
end
