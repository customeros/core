defmodule Core.WebTracker.SessionAnalyzer.TouchpointBuilder do
  @moduledoc """
  Responsible for building and analyzing user touchpoints from web tracking session data.

  This module processes web session events to construct touchpoints, which represent
  meaningful user interactions with the website. It handles:
  - Session event aggregation and organization
  - Pageview tracking and analysis
  - Event data cleaning and structuring
  - Touchpoint evaluation and metrics calculation
  """

  require Logger

  import Ecto.Query

  alias Core.Repo
  alias Core.WebTracker.Sessions
  alias Core.WebTracker.Events.Event

  @err_not_found {:error, "touchpoint events not found"}

  def build_touchpoints(session_id) do
    with {:ok, _session} <- Sessions.get_session_by_id(session_id),
         {:ok, _events} <- get_all_session_events(session_id) do
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

  def get_all_session_events(session_id) do
    events =
      Event
      |> where([e], e.session_id == ^session_id)
      |> order_by([e], asc: e.inserted_at)
      |> Repo.all()

    case events do
      [] ->
        @err_not_found

      results ->
        # Extract common session data from first event
        first_event = List.first(results)

        pageviews =
          results
          |> Enum.filter(fn event -> event.event_type == "page_view" end)
          |> Enum.map(fn event ->
            uri = URI.parse(event.href)
            "#{uri.scheme}://#{uri.host}#{uri.path}"
          end)

        events_map =
          results
          |> Enum.group_by(fn event ->
            uri = URI.parse(event.href)
            "#{uri.scheme}://#{uri.host}#{uri.path}"
          end)
          |> Enum.map(fn {url, events} ->
            # Strip duplicated data from events
            clean_events =
              Enum.map(events, fn event ->
                %{
                  id: event.id,
                  event_type: event.event_type,
                  event_data: event.event_data,
                  timestamp: event.timestamp,
                  inserted_at: event.inserted_at,
                  updated_at: event.updated_at
                }
              end)

            {url, clean_events}
          end)
          |> Enum.into(%{})

        {:ok,
         %{
           # Common session data
           session_id: first_event.session_id,
           tenant_id: first_event.tenant_id,
           visitor_id: first_event.visitor_id,
           ip: first_event.ip,
           user_agent: first_event.user_agent,
           language: first_event.language,
           screen_resolution: first_event.screen_resolution,
           cookies_enabled: first_event.cookies_enabled,
           referrer: first_event.referrer,
           origin: first_event.origin,
           hostname: first_event.hostname,

           # Unique data
           pageviews: pageviews,
           events_map: events_map
         }}
    end
  end
end
