defmodule Core.WebTracker.ChannelClassifier do
  @moduledoc """
  Classifies web traffic sources into marketing channels.

  This module analyzes referrer URLs and query parameters to categorize
  web traffic into different channels: direct traffic, paid search,
  organic search, and other marketing sources. It handles UTM parameter
  detection and self-referral identification.
  """

  require Logger

  alias Core.Utils.DomainExtractor
  alias Core.WebTracker.QueryParamAnalyzer
  alias Core.WebTracker.SearchPlatformDetector

  def classify(tenant_domains, referrer, query_params) do
    cond do
      direct?(tenant_domains, referrer, query_params) ->
        :direct

      SearchPlatformDetector.paid_search?(query_params) ->
        :paid_search

      SearchPlatformDetector.organic_search?(referrer, query_params) ->
        :organic_search
    end
  end

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

  defp direct?(tenant_domains, referrer, query_params) do
    cond do
      QueryParamAnalyzer.has_utm_params?(query_params) -> false
      is_nil(referrer) or referrer == "" -> true
      self_referral?(tenant_domains, referrer) -> true
      true -> false
    end
  end
end
