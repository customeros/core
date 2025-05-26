defmodule Core.Researcher.Orchestrator do
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

  def evaluate_icp_fit(tenant_id, lead_id, domain) do
    GenServer.cast(@name, {:evaluate_icp_fit, tenant_id, lead_id, domain})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:evaluate_icp_fit, tenant_id, lead_id, domain}, state) do
    Task.start(fn ->
      case Core.Researcher.IcpFitEvaluator.evaluate(tenant_id, domain) do
        {:ok, icp_fit} ->
          process_icp_evaluation(tenant_id, lead_id, icp_fit)

        {:error, reason} ->
          {:error, reason}
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:create_tenant_icp, tenant_id}, state) do
    Task.start(fn ->
      case Core.Researcher.IcpBuilder.build_for_tenant(tenant_id) do
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

  defp process_icp_evaluation(tenant_id, lead_id, icp_fit) do
    with {:ok, lead} <- Core.Crm.Leads.get_by_id(tenant_id, lead_id),
         stage <- determine_stage(icp_fit),
         {:ok, updated_lead} <-
           Core.Crm.Leads.update_lead(lead, %{stage: stage}) do
      {:ok, updated_lead}
    else
      {:error, reason} -> {:error, reason}
      nil -> {:error, :lead_not_found}
    end
  end

  defp determine_stage(:strong), do: :education
  defp determine_stage(:moderate), do: :education
  defp determine_stage(:not_a_fit), do: :not_a_fit
end
