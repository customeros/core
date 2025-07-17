defmodule Core.WebTracker.SessionAnalyzer.CampaignIdentifier do
  require Logger

  alias Core.Repo
  alias Core.WebTracker.Events
  alias Core.WebTracker.Sessions
  alias Core.WebTracker.Sessions.Session
  alias Core.WebTracker.SessionAnalyzer.ChannelClassifier.QueryParamAnalyzer

  def identify_campaigns(session_id) do
    with {:ok, session} <- Sessions.get_session_by_id(session_id),
         {:ok, event} <- Events.get_first_event(session_id) do
      case has_query_params?(event) do
        true -> set_campaigns_on_session(session, event.search)
        false -> {:ok, session}
      end
    else
      {:error, reason} ->
        Logger.error(
          "Failed to identify campaigns for session #{session_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp set_campaigns_on_session(session, query_string) do
    utm_id = get_utm_campaign(session.tenant_id, query_string)
    paid_id = get_paid_campaign(session.tenant_id, query_string)

    session
    |> Session.changeset(%{utm_id: utm_id, paid_id: paid_id})
    |> Repo.update()
  end

  defp get_utm_campaign(tenant_id, query_string) do
    case QueryParamAnalyzer.has_utm_params?(query_string) do
      true ->
        case QueryParamAnalyzer.get_utm_campaign(tenant_id, query_string) do
          {:ok, campaign} ->
            campaign.id

          {:error, reason} ->
            Logger.error("Failed to get utm campaign: #{inspect(reason)}", %{
              query_string: query_string,
              tenant_id: tenant_id
            })
            nil
        end

      false ->
        nil
    end
  end

  defp get_paid_campaign(tenant_id, query_string) do
    case QueryParamAnalyzer.has_paid_campaign_params?(query_string) do
      true ->
        case QueryParamAnalyzer.get_paid_campaign(tenant_id, query_string) do
          {:ok, campaign} ->
            campaign.id

          {:error, reason} ->
            Logger.error("Failed to get paid campaign: #{inspect(reason)}", %{
              query_string: query_string,
              tenant_id: tenant_id
            })
            nil
        end

      false ->
        nil
    end
  end

  defp has_query_params?(event) do
    case event.search do
      nil -> false
      "" -> false
      _ -> true
    end
  end
end
