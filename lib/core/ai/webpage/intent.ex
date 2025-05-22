defmodule Core.Ai.Webpage.Intent do
  @derive Jason.Encoder
  @type buyer_journey_stage :: 1..5
  @type t :: %__MODULE__{
          problem_recognition: buyer_journey_stage(),
          solution_research: buyer_journey_stage(),
          evaluation: buyer_journey_stage(),
          purchase_readiness: buyer_journey_stage()
        }
  defstruct [
    :problem_recognition,
    :solution_research,
    :evaluation,
    :purchase_readiness
  ]
end
