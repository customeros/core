defmodule Core.WebTracker.VisitorIntentPipeline do
  @moduledoc """

  """

  def start() do
    Task.Supervisor.start_child(
      Core.TaskSupervisor,
      fn ->
        visitor_intent_pipeline()
      end
    )
  end

  def visitor_intent_pipeline() do
  end
end
