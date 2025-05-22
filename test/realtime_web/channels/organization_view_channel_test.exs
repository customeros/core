defmodule Web.OrganizationChannelTest do
  use Web.ChannelCase
  require Logger

  setup do
    {:ok, _, socket} =
      Web.UserSocket
      |> socket("token", %{token: "123"})
      |> subscribe_and_join(
        Web.OrganizationViewChannel,
        "organization_presence:123",
        %{
          user_id: "USER.ID",
          username: "Max Mustermann"
        }
      )

    %{socket: socket}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push(socket, "ping", %{"hello" => "there"})
    Logger.debug("Ref: #{inspect(ref)}")
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  test "shout broadcasts to organization:lobby", %{socket: socket} do
    push(socket, "shout", %{"hello" => "all"})
    assert_broadcast "shout", %{"hello" => "all"}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    send(socket.channel_pid, {:broadcast, "broadcast", %{"some" => "data"}})
    assert_push "broadcast", %{"some" => "data"}
  end

  test "broadcasting presence", %{socket: _socket} do
    # Wait for the presence state message
    assert_push "presence_state", presence_state
    assert is_map(presence_state)
    assert Map.has_key?(presence_state, "USER.ID")

    # Verify the presence data structure
    user_presence = presence_state["USER.ID"]
    assert is_map(user_presence)
    assert Map.has_key?(user_presence, :metas)
    assert length(user_presence.metas) > 0

    # Verify the metadata
    meta = List.first(user_presence.metas)
    assert meta.metadata["source"] == "customerOS"
    assert meta.username == "Max Mustermann"
    assert is_binary(meta.online_at)

    on_exit(fn ->
      for pid <- Web.Presence.fetchers_pids() do
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, _, _, _}, 1000
      end
    end)
  end
end
