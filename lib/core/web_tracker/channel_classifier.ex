defmodule Core.WebTracker.ChannelClassifier do
  @moduledoc """
  Classifies web traffic sources into marketing channels.
  This module analyzes referrer URLs and query parameters to categorize
  web traffic into different channels: direct traffic, paid search,
  organic search, and other marketing sources. It handles UTM parameter
  detection and self-referral identification.
  """
  require Logger
  alias Core.WebTracker.Events
  alias Core.Utils.DomainExtractor
  alias Core.WebTracker.EmailDetector
  alias Core.WebTracker.QueryParamAnalyzer
  alias Core.WebTracker.SearchPlatformDetector
  alias Core.WebTracker.SocialPlatformDetector
  alias Core.WebTracker.WorkplacePlatformDetector

  @err_unable_to_classify {:error,
                           "unable to determine channel attribution for session"}

  def classify_session(session_id, tenant_domains) do
    case Events.get_first_event(session_id) do
      {:ok, event} ->
        classify(tenant_domains, event.referrer, event.search, event.user_agent)

      {:error, :not_found} ->
        Logger.error("unable to determine channel for session", %{
          session_id: session_id
        })

        @err_unable_to_classify
    end
  end

  def classify(_tenant_domains, nil, _query_params, _user_agent), do: :direct

  def classify(tenant_domains, referrer, query_params, user_agent) do
    cond do
      SearchPlatformDetector.paid_search?(query_params) ->
        :paid_search

      SocialPlatformDetector.paid_social?(query_params) ->
        :paid_social

      SearchPlatformDetector.organic_search?(referrer, query_params) ->
        :organic_search

      SocialPlatformDetector.organic_social?(referrer, query_params) ->
        :organic_social

      SocialPlatformDetector.in_app_browser?(user_agent) ->
        :organic_social

      EmailDetector.email_traffic?(referrer, query_params) ->
        :email

      WorkplacePlatformDetector.workplace?(referrer) ->
        :workplace_tools

      direct?(tenant_domains, referrer, query_params) ->
        :direct

      has_referrer?(referrer) ->
        :referral

      true ->
        :direct
    end
  end

  defp direct?(tenant_domains, referrer, query_params) do
    cond do
      QueryParamAnalyzer.has_utm_params?(query_params) -> false
      is_nil(referrer) or referrer == "" -> true
      self_referral?(tenant_domains, referrer) -> true
      true -> false
    end
  end

  defp has_referrer?(referrer) when is_binary(referrer) and referrer != "" do
    case URI.parse(referrer) do
      %URI{host: host} when is_binary(host) and host != "" -> true
      _ -> false
    end
  end

  defp has_referrer?(_), do: false

  defp self_referral?(tenant_domains, referrer) do
    case DomainExtractor.extract_base_domain(referrer) do
      {:ok, referrer_domain} ->
        referrer_domain in tenant_domains

      {:error, reason} ->
        Logger.error("failed to determine if referrer is internal", %{
          tenant_domains: tenant_domains,
          referrer: referrer,
          reason: reason
        })

        false
    end
  end
end
