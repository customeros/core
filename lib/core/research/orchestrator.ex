defmodule Core.Research.Orchestrator do
  alias Task
  use GenServer
  require Logger

  @name __MODULE__

  def start_link(opts \\ []) do
    opts = Keyword.merge([name: @name], opts)
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def create_icp_for_tenant(tenant_id) do
    GenServer.cast(@name, {:create_tenant_icp, tenant_id})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:create_tenant_icp, tenant_id}, state) do
    Task.start_link(fn ->
      case Core.Research.IcpBuilder.build_for_tenant(tenant_id) do
        {:ok, _profile} ->
          Phoenix.PubSub.broadcast(
            Core.PubSub,
            "icp",
            {:icp_created, tenant_id}
          )

          Logger.info("ICP Profile created for #{tenant_id}")

        {:error, reason} ->
          Phoenix.PubSub.broadcast(
            Core.PubSub,
            "icp",
            {:icp_failed, tenant_id, reason}
          )

          Logger.info("ICP Profile failed for #{tenant_id}: #{reason}")
      end
    end)

    {:noreply, state}
  end
end
