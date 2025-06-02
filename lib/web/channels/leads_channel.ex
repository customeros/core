defmodule Web.Channels.LeadsChannel do
  @moduledoc """
  Phoenix Channel for managing real-time lead interactions and presence.

  This channel handles:
  * Lead-related real-time updates
  * User presence tracking for lead views
  * User color assignment for lead interactions
  * Broadcasting lead-related events
  * Managing user sessions and presence state

  It integrates with the color management system to assign unique colors
  to users viewing leads and uses Phoenix.Presence for tracking user
  presence across the leads interface.
  """

  use Web, :channel
  require Logger
  alias Web.Presence
  alias Core.Auth.Users.ColorManager

  @impl true
  def join("leads:" <> tenant_id, params, socket) do
    {:ok, color} = ColorManager.assign_color(params["user_id"])

    socket =
      socket
      |> assign(:user_id, params["user_id"])
      |> assign(:username, params["username"])
      |> assign(user_color: %{params["user_id"] => color})

    send(self(), {:after_join, tenant_id, params})
    {:ok, socket}
  end

  @impl true
  def join(_, _, _) do
    {:ok, self()}
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
  def handle_info({:after_join, tenant_id, params}, socket) do
    {:ok, _} =
      Presence.track(
        self(),
        "leads:#{tenant_id}",
        params["user_id"],
        %{
          username: params["username"],
          online_at: inspect(System.system_time(:second)),
          metadata: %{"source" => "customerOS"},
          color: Map.get(socket.assigns.user_color, params["user_id"]),
          user_id: params["user_id"]
        }
      )

    push(socket, "presence_state", Presence.list("leads:#{tenant_id}"))
    {:noreply, socket}
  end

  @impl true
  def terminate(_, socket) do
    ColorManager.release_color(socket.assigns.user_id)
    {:ok, socket}
  end
end
