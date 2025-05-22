defmodule Core.Icp.Service do
  use GenServer

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
      Core.Icp.BuildProfile.start_for_tenant(tenant_id)
    end)

    {:noreply, state}
  end
end
