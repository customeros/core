defmodule Core.WebTracker.SessionAnalyzer.TouchpointBuilder do
  require Logger

  # import Ecto.Query

  # alias Core.Repo
  alias Core.WebTracker.Events
  alias Core.WebTracker.Sessions
  # alias Core.WebTracker.Events.Event

  # @err_not_found {:error, "touchpoint events not found"}

  def build_touchpoints(session_id) do
    with {:ok, _session} <- Sessions.get_session_by_id(session_id),
         {:ok, _pages} <- Events.get_visited_pages(session_id) do
      :ok
    else
      _ -> :error
    end
  end

  # defp build_touchpoint(session_id, url) do
  #   case get_touchpoint_events(session_id, url) do
  #     @err_not_found ->
  #       @err_not_found
  #
  #     {:ok, events} ->
  #       evaluate_touchpoint(events)
  #   end
  # end
  #
  # defp evaluate_touchpoint(_events) do
  #   :ok
  # end

  # def clicks_count(events) do
  # end
  #
  # def identify_event?(events) do
  # end
  #
  # def attention_in_seconds(events) do
  # end
  #
  # def is_internal_referrer?(events) do
  # end

  # defp get_touchpoint_events(session_id, url) do
  #   events =
  #     Event
  #     |> where([e], e.session_id == ^session_id and e.href == ^url)
  #     |> order_by([e], asc: e.inserted_at)
  #     |> Repo.all()
  #
  #   case events do
  #     [] -> @err_not_found
  #     results -> {:ok, results}
  #   end
  # end
end
