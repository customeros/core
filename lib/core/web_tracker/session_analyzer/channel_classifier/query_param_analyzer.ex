defmodule Core.WebTracker.SessionAnalyzer.ChannelClassifier.QueryParamAnalyzer do
  @moduledoc """
  Analyzes query parameters to detect UTM tracking parameters and paid campaign data.
  This module provides utilities for parsing and analyzing URL query parameters,
  specifically focused on detecting UTM parameters (utm_source, utm_medium,
  utm_campaign, utm_term, utm_content) used for marketing campaign tracking,
  as well as platform-specific paid campaign parameters and HubSpot managed campaigns.
  """

  alias Core.WebTracker.Sessions.UtmCampaigns
  alias Core.WebTracker.Sessions.PaidCampaigns

  @utm_params [
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_term",
    "utm_content"
  ]

  def has_utm_params?(query_string) when is_binary(query_string) do
    query_string
    |> parse_query_params()
    |> has_any_utm_params?()
  end

  def has_utm_params?(_), do: false

  @doc """
  Parses query parameters into UTM and paid campaign data structures.
  """

  def get_paid_campaign(tenant_id, query_string) when is_binary(query_string) do
    case query_string
         |> parse_query_params()
         |> extract_paid_data(tenant_id) do
      nil -> {:ok, nil}
      data -> PaidCampaigns.upsert(data)
    end
  end

  def get_utm_campaign(tenant_id, query_string) when is_binary(query_string) do
    query_string
    |> parse_query_params()
    |> extract_utm_data(tenant_id)
    |> UtmCampaigns.upsert()
  end

  @doc """
  Determines if query parameters contain paid campaign tracking data.
  """
  def has_paid_campaign_params?(query_string) when is_binary(query_string) do
    query_string
    |> parse_query_params()
    |> determine_platform()
    |> is_atom()
  end

  def has_paid_campaign_params?(_), do: false

  defp parse_query_params(query_string) do
    query_string
    |> String.trim_leading("?")
    |> URI.decode_query()
  end

  defp has_any_utm_params?(param_map) when is_map(param_map) do
    Enum.any?(@utm_params, fn param ->
      case Map.get(param_map, param) do
        nil -> false
        "" -> false
        _value -> true
      end
    end)
  end

  defp extract_utm_data(params, tenant_id) do
    utm_params = %{
      tenant_id: tenant_id,
      utm_source: decode_string(Map.get(params, "utm_source")),
      utm_medium: decode_string(Map.get(params, "utm_medium")),
      utm_campaign: decode_string(Map.get(params, "utm_campaign")),
      utm_term: decode_string(Map.get(params, "utm_term")),
      utm_content: decode_string(Map.get(params, "utm_content"))
    }

    filter_empty_values(utm_params)
  end

  defp decode_string(string) when is_binary(string) do
    case String.contains?(string, "%") and
           String.match?(string, ~r/%[0-9A-Fa-f]{2}/) do
      true -> URI.decode(string)
      false -> string
    end
  end

  defp decode_string(_), do: nil

  defp extract_paid_data(params, tenant_id) do
    platform = determine_platform(params)

    if platform do
      base_params = extract_platform_params(params, platform)

      if map_size(base_params) > 0 do
        Map.merge(base_params, %{
          tenant_id: tenant_id,
          platform: platform
        })
      else
        nil
      end
    else
      nil
    end
  end

  defp determine_platform(params) do
    utm_source = Map.get(params, "utm_source")

    case utm_source do
      "bing" ->
        :bing

      "microsoft" ->
        :bing

      "msn" ->
        :bing

      "adwords" ->
        :google

      "google" ->
        :google

      "facebook" ->
        :facebook

      "linkedin" ->
        :linkedin

      "youtube" ->
        :youtube

      "instagram" ->
        :instagram

      "ig" ->
        :instagram

      "tiktok" ->
        :tiktok

      "twitter" ->
        :x

      _ ->
        cond do
          Map.has_key?(params, "gclid") -> :google
          Map.has_key?(params, "msclkid") -> :bing
          Map.has_key?(params, "fbclid") -> :facebook
          Map.has_key?(params, "li_fat_id") -> :linkedin
          Map.has_key?(params, "hsa_acc") -> :other
          true -> nil
        end
    end
  end

  defp extract_platform_params(params, platform) do
    case platform do
      platform when platform in [:facebook, :instagram] ->
        extract_facebook_params(params)

      platform when platform in [:google, :youtube] ->
        extract_google_params(params)

      :linkedin ->
        extract_linkedin_params(params)

      :x ->
        extract_twitter_params(params)

      :bing ->
        extract_bing_params(params)

      _ ->
        extract_hsa_params(params)
    end
  end

  defp extract_facebook_params(params) do
    %{
      account_id: Map.get(params, "igshid") || Map.get(params, "fbclid"),
      campaign_id:
        Map.get(params, "ig_campaign_id") || Map.get(params, "fbc_id"),
      group_id:
        Map.get(params, "ig_adset_id") || Map.get(params, "fb_adset_id"),
      targeting_id:
        Map.get(params, "ig_targeting_id") || Map.get(params, "fb_targeting_id"),
      content_id:
        Map.get(params, "ig_ad_id") || Map.get(params, "h_ad_id") ||
          Map.get(params, "fb_ad_id")
    }
    |> filter_empty_values()
  end

  defp extract_google_params(params) do
    %{
      account_id: Map.get(params, "gclid"),
      campaign_id:
        Map.get(params, "gc_id") || Map.get(params, "gad_campaignid"),
      group_id: Map.get(params, "h_ga_id"),
      targeting_id:
        Map.get(params, "h_keyword_id") || Map.get(params, "h_placement"),
      content_id: Map.get(params, "h_ad_id")
    }
    |> filter_empty_values()
  end

  defp extract_twitter_params(params) do
    %{
      account_id:
        Map.get(params, "twclid") || Map.get(params, "twitter_account_id"),
      campaign_id:
        Map.get(params, "tw_campaign_id") ||
          Map.get(params, "twitter_campaign_id"),
      group_id:
        Map.get(params, "tw_adgroup_id") ||
          Map.get(params, "twitter_adgroup_id"),
      targeting_id:
        Map.get(params, "tw_targeting_id") ||
          Map.get(params, "twitter_targeting_id"),
      content_id:
        Map.get(params, "tw_ad_id") || Map.get(params, "twitter_ad_id")
    }
    |> filter_empty_values()
  end

  defp extract_linkedin_params(params) do
    %{
      account_id:
        Map.get(params, "li_fat_id") || Map.get(params, "linkedin_account_id"),
      campaign_id:
        Map.get(params, "li_campaign_id") ||
          Map.get(params, "linkedin_campaign_id"),
      group_id:
        Map.get(params, "li_adgroup_id") ||
          Map.get(params, "linkedin_adgroup_id"),
      targeting_id:
        Map.get(params, "li_targeting_id") ||
          Map.get(params, "linkedin_targeting_id"),
      content_id:
        Map.get(params, "li_ad_id") || Map.get(params, "linkedin_ad_id")
    }
    |> filter_empty_values()
  end

  defp extract_bing_params(params) do
    %{
      account_id:
        Map.get(params, "msclkid") || Map.get(params, "ms_account_id"),
      campaign_id:
        Map.get(params, "ms_campaign_id") || Map.get(params, "bing_campaign_id"),
      group_id:
        Map.get(params, "ms_adgroup_id") || Map.get(params, "bing_adgroup_id"),
      targeting_id:
        Map.get(params, "ms_targeting_id") || Map.get(params, "bing_keyword_id"),
      content_id: Map.get(params, "ms_ad_id") || Map.get(params, "bing_ad_id")
    }
    |> filter_empty_values()
  end

  defp extract_hsa_params(params) do
    %{
      account_id: Map.get(params, "hsa_acc"),
      campaign_id: Map.get(params, "hsa_cam"),
      group_id: Map.get(params, "hsa_grp"),
      targeting_id: Map.get(params, "hsa_tgt"),
      content_id: Map.get(params, "hsa_ad")
    }
    |> filter_empty_values()
  end

  defp filter_empty_values(map) do
    map
    |> Enum.reject(fn {_k, v} -> v == nil or v == "" end)
    |> Enum.into(%{})
  end
end
