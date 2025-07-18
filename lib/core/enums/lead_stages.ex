defmodule Core.Enums.LeadStages do
  @moduledoc """
  Defines the possible stages in a lead's journey through the sales pipeline.

  Stages progress from initial contact (pending) through various engagement phases
  to final conversion (customer).
  """

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
