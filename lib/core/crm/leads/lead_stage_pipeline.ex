defmodule Core.Crm.Leads.LeadStagePipeline do
  @moduledoc """

  """

  require Logger

  def start() do
    Task.Supervisor.start_child(
      Core.TaskSupervisor,
      fn ->
        determine_stage()
      end
    )
  end

  def determine_stage() do
    Logger.metadata(module: __MODULE__, function: :determine_stage)
  end
end
