defmodule Core.WebTracker.SessionAnalyzer.ChannelClassifier do
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
  alias Core.WebTracker.SessionAnalyzer.ChannelClassifier.EmailDetector
  alias Core.WebTracker.SessionAnalyzer.ChannelClassifier.QueryParamAnalyzer
  alias Core.WebTracker.SessionAnalyzer.ChannelClassifier.SearchPlatformDetector
  alias Core.WebTracker.SessionAnalyzer.ChannelClassifier.SocialPlatformDetector

  alias Core.WebTracker.SessionAnalyzer.ChannelClassifier.WorkplacePlatformDetector

  @err_unable_to_classify {:error,
                           "unable to determine channel attribution for session"}

  def classify_session(session_id) do
    with {:ok, session} <- Sessions.get_session_by_id(session_id),
         {:ok, event} <- Events.get_first_event(session_id),
         {:ok, tenant_domains} when not is_nil(session.tenant_id) <-
           Tenants.get_tenant_domains(session.tenant_id) do
      referrer = event.referrer |> to_string() |> String.trim_trailing("/")

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
        Logger.error(
          "unable to determine channel for session: #{inspect(reason)}",
          %{
            session_id: session_id,
            reason: reason
          }
        )

        @err_unable_to_classify
    end
  end

  defp classify_traffic(tenant_domains, referrer, query_params, user_agent) do
    cond do
      direct_traffic?(tenant_domains, referrer, query_params) ->
        {:direct, nil}

      WorkplacePlatformDetector.workplace?(referrer) ->
        platform =
          WorkplacePlatformDetector.get_platform(referrer, query_params)

        {:workplace_tools, platform}

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
      amp_self_referral?(referrer, tenant_domains) -> true
      internal_tool_referrer?(referrer) -> true
      true -> false
    end
  end

  defp has_valid_referrer?(referrer)
       when is_binary(referrer) and referrer != "" do
    if String.starts_with?(referrer, "android-app://") or
         String.starts_with?(referrer, "ios-app://") do
      false
    else
      case URI.parse(referrer) do
        %URI{host: host} when is_binary(host) and host != "" -> true
        _ -> false
      end
    end
  end

  defp has_valid_referrer?(_), do: false

  defp self_referral?(tenant_domains, referrer) do
    if String.starts_with?(referrer || "", "android-app://") or
         String.starts_with?(referrer || "", "ios-app://") do
      false
    else
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

  defp amp_self_referral?(referrer, tenant_domains) do
    case URI.parse(referrer || "") do
      %URI{host: host} when is_binary(host) ->
        String.contains?(host, "ampproject.org") and
          Enum.any?(tenant_domains, fn domain ->
            String.contains?(host, String.replace(domain, ".", "-"))
          end)

      _ ->
        false
    end
  end

  defp internal_tool_referrer?(referrer) do
    hubspot_internal_patterns = [
      "hubspotpreview-na1.com",
      "hubspotpreview-eu1.com",
      "hubspot.com/preview",
      "_preview=true"
    ]

    Enum.any?(hubspot_internal_patterns, fn pattern ->
      String.contains?(referrer || "", pattern)
    end)
  end
end
