defmodule Core.Crm.Leads.LeadStagePipeline do
  @moduledoc """
  Manages the automated pipeline for lead stage transitions.

  This module is responsible for:
  * Evaluating and determining appropriate stage transitions for leads
  * Running stage evaluation asynchronously via task supervisor
  * Coordinating the stage transition process

  The pipeline ensures leads progress through their lifecycle stages
  based on predefined criteria and business rules.
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
