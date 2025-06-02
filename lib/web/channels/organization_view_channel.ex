defmodule Web.OrganizationViewChannel do
  @moduledoc """
  Phoenix Channel for managing organization presence and real-time updates.

  This channel handles:
  * Organization presence tracking
  * Real-time user presence updates
  * Broadcasting organization-wide messages
  * User online/offline status management

  It uses Phoenix.Presence to track which users are currently viewing
  an organization and provides real-time updates to all connected clients.
  """

  use Web, :channel
  require Logger

  @impl true
  def join("organization_presence:" <> organization_id, params, socket) do
    send(self(), {:after_join, organization_id, params})
    {:ok, socket}
  end

  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  @impl true
  def handle_in("shout", payload, socket) do
    broadcast!(socket, "shout", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:broadcast, event, payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:after_join, organization_id, params}, socket) do
    {:ok, _} =
      Web.Presence.track(
        self(),
        "organization_presence:#{organization_id}",
        params["user_id"],
        %{
          username: params["username"],
          online_at: inspect(System.system_time(:second)),
          metadata: %{"source" => "customerOS"}
        }
      )

    push(
      socket,
      "presence_state",
      Web.Presence.list("organization_presence:#{organization_id}")
    )

    {:noreply, socket}
  end
end
