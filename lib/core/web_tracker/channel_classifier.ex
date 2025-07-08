defmodule Core.WebTracker.ChannelClassifier do
  @moduledoc """
  Classifies web traffic sources into marketing channels.
  This module analyzes referrer URLs and query parameters to categorize
  web traffic into different channels: direct traffic, paid search,
  organic search, and other marketing sources. It handles UTM parameter
  detection and self-referral identification.
  """
  require Logger

  alias Core.Auth.Tenants
  alias Core.WebTracker.Events
  alias Core.WebTracker.Sessions
  alias Core.Utils.DomainExtractor
  alias Core.WebTracker.EmailDetector
  alias Core.WebTracker.QueryParamAnalyzer
  alias Core.WebTracker.SearchPlatformDetector
  alias Core.WebTracker.SocialPlatformDetector
  alias Core.WebTracker.WorkplacePlatformDetector

  @err_unable_to_classify {:error,
                           "unable to determine channel attribution for session"}

  def classify_session(session_id) do
    with {:ok, session} <- Sessions.get_session_by_id(session_id),
         {:ok, tenant} <- Tenants.get_tenant_by_name(session.tenant),
         {:ok, event} <- Events.get_first_event(session_id),
         {:ok, tenant_domains} <-
           Tenants.get_tenant_domains(tenant.id) do
      referrer = String.trim_trailing(event.referrer, "/")

      classification =
        classify_traffic(
          tenant_domains,
          referrer,
          event.search,
          event.user_agent
        )

      update_session_classification(session_id, classification)
    else
      {:error, reason} ->
        Logger.error("unable to determine channel for session", %{
          session_id: session_id,
          reason: reason
        })

        @err_unable_to_classify
    end
  end

  defp classify_traffic(tenant_domains, referrer, query_params, user_agent) do
    cond do
      direct_traffic?(tenant_domains, referrer, query_params) ->
        {:direct, nil}

      SearchPlatformDetector.paid_search?(query_params) ->
        platform = SearchPlatformDetector.get_platform(referrer, query_params)
        {:paid_search, platform}

      SocialPlatformDetector.paid_social?(query_params) ->
        platform =
          SocialPlatformDetector.get_platform(
            referrer,
            query_params,
            user_agent
          )

        {:paid_social, platform}

      SearchPlatformDetector.organic_search?(referrer, query_params) ->
        platform = SearchPlatformDetector.get_platform(referrer, query_params)
        {:organic_search, platform}

      SocialPlatformDetector.organic_social?(referrer, query_params) or
          SocialPlatformDetector.in_app_browser?(user_agent) ->
        platform =
          SocialPlatformDetector.get_platform(
            referrer,
            query_params,
            user_agent
          )

        {:organic_social, platform}

      EmailDetector.email_traffic?(referrer, query_params) ->
        {:email, nil}

      WorkplacePlatformDetector.workplace?(referrer) ->
        platform =
          WorkplacePlatformDetector.get_platform(referrer, query_params)

        {:workplace_tools, platform}

      has_valid_referrer?(referrer) ->
        referrer_domain = DomainExtractor.extract_base_domain(referrer)
        {:referral, referrer_domain}

      true ->
        {:direct, nil}
    end
  end

  defp update_session_classification(session_id, {:referral, referral_result}) do
    case referral_result do
      {:ok, domain} when is_binary(domain) ->
        Sessions.set_channel_classification(session_id, :referral, %{
          referrer: domain
        })

      {:error, _reason} ->
        Sessions.set_channel_classification(session_id, :referral)
    end
  end

  defp update_session_classification(session_id, {channel, platform_result}) do
    case platform_result do
      {:ok, platform} ->
        Sessions.set_channel_classification(session_id, channel, %{
          platform: platform
        })

      :not_found ->
        Sessions.set_channel_classification(session_id, channel)

      nil ->
        Sessions.set_channel_classification(session_id, channel)
    end
  end

  defp direct_traffic?(tenant_domains, referrer, query_params) do
    cond do
      QueryParamAnalyzer.has_utm_params?(query_params) -> false
      is_nil(referrer) or referrer == "" -> true
      self_referral?(tenant_domains, referrer) -> true
      true -> false
    end
  end

  defp has_valid_referrer?(referrer)
       when is_binary(referrer) and referrer != "" do
    case URI.parse(referrer) do
      %URI{host: host} when is_binary(host) and host != "" -> true
      _ -> false
    end
  end

  defp has_valid_referrer?(_), do: false

  defp self_referral?(tenant_domains, referrer) do
    case DomainExtractor.extract_base_domain(referrer) do
      {:ok, referrer_domain} ->
        referrer_domain in tenant_domains

      {:error, reason} ->
        Logger.error("failed to determine if referrer is internal", %{
          referrer: referrer,
          reason: reason
        })

        false
    end
  end
end
