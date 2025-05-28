defmodule Web.Channels.EventsChannel do
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
  def handle_in("event", %{"event" => event}, socket) do
    broadcast!(socket, "event", %{event: event})
    {:reply, :ok, socket}
  end

  @impl true
  def terminate(_, socket) do
    {:ok, socket}
  end
end
