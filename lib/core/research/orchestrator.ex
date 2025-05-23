defmodule Core.Research.Orchestrator do
  alias Task
  use GenServer
  require Logger
  # Fixed: was **MODULE**
  @name __MODULE__

  def start_link(opts \\ []) do
    opts = Keyword.merge([name: @name], opts)
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def create_icp_for_tenant(tenant_id) do
    GenServer.cast(@name, {:create_tenant_icp, tenant_id})
  end

  def evaluate_icp_fit(tenant_id, domain) do
    GenServer.cast(@name, {:evaluate_icp_fit, tenant_id, domain})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:evaluate_icp_fit, tenant_id, domain}, state) do
    Task.start(fn ->
      case Core.Research.IcpFitEvaluator.evaluate(tenant_id, domain) do
        {:ok, icp_fit} ->
          Phoenix.PubSub.broadcast(
            Core.PubSub,
            "icp_fit",
            {:icp_fit_evaluated, tenant_id, domain, icp_fit}
          )

          Logger.info(
            "ICP fit evaluated for tenant #{tenant_id}, domain #{domain}: #{icp_fit}"
          )

        {:error, reason} ->
          Phoenix.PubSub.broadcast(
            Core.PubSub,
            "icp_fit",
            {:icp_fit_failed, tenant_id, domain, reason}
          )

          Logger.error(
            "ICP fit evaluation failed for tenant #{tenant_id}, domain #{domain}: #{reason}"
          )
      end
    end)

    # Added missing return tuple
    {:noreply, state}
  end

  @impl true
  def handle_cast({:create_tenant_icp, tenant_id}, state) do
    Task.start(fn ->
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

          Logger.error("ICP Profile failed for #{tenant_id}: #{reason}")
      end
    end)

    {:noreply, state}
  end
end
