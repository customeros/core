defmodule Core.WebTracker.StageIdentifier do
  alias Core.WebTracker.StageIdentifier.SessionContext

  def identify(page_visits)
      when is_list(page_visits) and length(page_visits) > 0 do
    if Enum.all?(page_visits, &match?(%SessionContext{}, &1)) do
      page_visits
      |> calculate_session_stage_scores()
      |> determine_primary_stage()
    else
      {:error, :invalid_struct_type}
    end
  end

  def identify(_), do: {:error, :invalid_input}

  defp calculate_session_stage_scores(page_visits) do
    totals =
      Enum.reduce(
        page_visits,
        %{
          total_problem_recognition: 0,
          total_solution_research: 0,
          total_evaluation: 0,
          total_purchase_readiness: 0
        },
        fn page, acc ->
          intent = elem(page, 2)

          %{
            total_problem_recognition:
              acc.total_problem_recognition + intent.problem_recognition,
            total_solution_research:
              acc.total_solution_research + intent.solution_research,
            total_evaluation: acc.total_evaluation + intent.evaluation,
            total_purchase_readiness:
              acc.total_purchase_readiness + intent.purchase_readiness
          }
        end
      )

    {:ok, totals}
  end

  defp determine_primary_stage({:ok, totals}) do
    # Order matters - later stages win ties (more advanced in buyer journey)
    stage_scores = [
      {:education, totals.total_problem_recognition},
      {:solution, totals.total_solution_research},
      {:evaluation, totals.total_evaluation},
      {:ready_to_buy, totals.total_purchase_readiness}
    ]

    {primary_stage, _max_score} =
      stage_scores
      # Reverse so later stages win ties
      |> Enum.reverse()
      |> Enum.max_by(fn {_stage, score} -> score end)

    {:ok, primary_stage}
  end
end
