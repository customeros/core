defmodule Core.Enums.LeadStages do
  @lead_stage [
    :pending,
    :target,
    :education,
    :solution,
    :evaluation,
    :ready_to_buy,
    :customer
  ]

  def stages, do: @lead_stage
end
