defmodule Core.WebTracker.StageIdentifier do
  @moduledoc """
  Provides functions to identify the primary stage of a web session based on page visits and intent analysis.

  This module analyzes a list of page visits, each with associated intent, to determine the user's current stage in the buying or research process. It prioritizes high-purchase-readiness and evaluation stages, and otherwise calculates scores to select the most likely stage.
  """

  alias Core.WebTracker.StageIdentifier.SessionContext

  def identify(page_visits)
      when is_list(page_visits) and length(page_visits) > 0 do
    session_contexts =
      Enum.map(page_visits, fn {url, summary, intent} ->
        %SessionContext{url: url, summary: summary, intent: intent}
      end)

    session_contexts
    |> check_for_high_priority_stages()
    |> case do
      {:priority, stage} ->
        {:ok, stage}

      :continue ->
        session_contexts
        |> calculate_session_stage_scores()
        |> determine_primary_stage()
    end
  end

  def identify(_), do: {:error, :invalid_input}

  defp check_for_high_priority_stages(session_contexts) do
    has_max_purchase =
      Enum.any?(session_contexts, fn %SessionContext{intent: intent} ->
        intent.purchase_readiness == 5
      end)

    has_max_evaluation =
      Enum.any?(session_contexts, fn %SessionContext{intent: intent} ->
        intent.evaluation == 5
      end)

    cond do
      has_max_purchase -> {:priority, :ready_to_buy}
      has_max_evaluation -> {:priority, :evaluation}
      true -> :continue
    end
  end

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
