defmodule Core.Icp.Service do
  use GenServer

  @name __MODULE__

  def start_link(opts \\ []) do
    opts = Keyword.merge([name: @name], opts)
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def create_icp(domain) do
    GenServer.cast(@name, {:create_icp, domain})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:create_icp, domain}, state) do
    Task.start_link(fn -> Core.Icp.BuildProfile.start(domain) end)
    {:noreply, state}
  end
    
end
