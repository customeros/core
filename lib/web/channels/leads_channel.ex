defmodule Web.Channels.LeadsChannel do
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
