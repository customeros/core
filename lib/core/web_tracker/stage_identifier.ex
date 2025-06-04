defmodule Core.WebTracker.StageIdentifier do
  alias Core.WebTracker.StageIdentifier.SessionContext

  def identify(page_visits)
      when is_list(page_visits) and length(page_visits) > 0 do
    session_contexts =
      Enum.map(page_visits, fn {url, summary, intent} ->
        %SessionContext{url: url, summary: summary, intent: intent}
      end)

    session_contexts
    |> calculate_session_stage_scores()
    |> determine_primary_stage()
  end

  def identify(_), do: {:error, :invalid_input}

  defp calculate_session_stage_scores(session_contexts) do
    totals =
      Enum.reduce(
        session_contexts,
        %{
          total_problem_recognition: 0,
          total_solution_research: 0,
          total_evaluation: 0,
          total_purchase_readiness: 0
        },
        fn %SessionContext{intent: intent}, acc ->
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
    stage_scores = [
      {:education, totals.total_problem_recognition},
      {:solution, totals.total_solution_research},
      {:evaluation, totals.total_evaluation},
      {:ready_to_buy, totals.total_purchase_readiness}
    ]

    {primary_stage, _max_score} =
      stage_scores
      |> Enum.reverse()
      |> Enum.max_by(fn {_stage, score} -> score end)

    {:ok, primary_stage}
  end
end
