defmodule Core.WebTracker.SearchPlatformDetector do
  @moduledoc """
  Detects search platforms and distinguishes between paid and organic search traffic.

  This module analyzes referrer URLs and query parameters to identify search
  platforms (Google, Bing, Yahoo, etc.) and determine whether traffic comes
  from paid advertising campaigns or organic search results. It also handles
  mobile app referrers from search platforms.
  """

  alias Core.Utils.DomainExtractor

  @doc """
  Checks if the referrer and query params indicate paid search traffic.

  Returns true if query params contain paid search indicators.
  """
  def paid_search?(query_params) do
    case parse_query_string(query_params) do
      {:ok, param_map} ->
        has_paid_search_indicators?(param_map)

      {:error, _} ->
        false
    end
  end

  @doc """
  Checks if the referrer indicates organic search traffic.

  Returns true if referrer is from a search platform AND no paid indicators.
  """
  def organic_search?(referrer, query_params) do
    case get_platform_from_referrer(referrer) do
      {:ok, _platform} ->
        case parse_query_string(query_params) do
          {:ok, param_map} ->
            not has_paid_search_indicators?(param_map)

          {:error, _} ->
            true
        end

      :not_found ->
        false
    end
  end

  @doc """
  Gets the search platform from referrer or query params.

  Returns {:ok, :google} or :not_found
  """
  def get_platform(referrer, query_params) do
    case parse_query_string(query_params) do
      {:ok, param_map} ->
        case get_platform_from_params(param_map) do
          {:ok, platform} ->
            {:ok, platform}

          :not_found ->
            get_platform_from_referrer(referrer)
        end

      {:error, _} ->
        get_platform_from_referrer(referrer)
    end
  end

  @search_domains %{
    # Google
    "google.com" => :google,
    "www.google.com" => :google,
    "google.co.uk" => :google,
    "google.ca" => :google,
    "google.com.au" => :google,
    "google.de" => :google,
    "google.fr" => :google,
    "google.es" => :google,
    "google.it" => :google,
    "google.co.jp" => :google,
    "google.co.in" => :google,
    "google.com.br" => :google,
    "google.com.mx" => :google,
    "google.nl" => :google,
    "google.se" => :google,
    "google.no" => :google,
    "google.dk" => :google,
    "google.fi" => :google,
    "google.pl" => :google,
    "google.ru" => :google,
    "google.co.za" => :google,
    "google.com.sg" => :google,
    "google.com.hk" => :google,
    "google.co.kr" => :google,
    "google.com.tw" => :google,
    "google.co.th" => :google,
    "google.com.my" => :google,
    "google.co.id" => :google,
    "google.com.ph" => :google,
    "google.com.vn" => :google,

    # Bing/Microsoft
    "bing.com" => :bing,
    "www.bing.com" => :bing,
    "bing.co.uk" => :bing,
    "bing.ca" => :bing,
    "bing.com.au" => :bing,
    "bing.de" => :bing,
    "bing.fr" => :bing,
    "bing.es" => :bing,
    "bing.it" => :bing,
    "bing.co.jp" => :bing,
    "bing.com.br" => :bing,
    "bing.nl" => :bing,
    "bing.se" => :bing,
    "bing.no" => :bing,
    "bing.dk" => :bing,
    "bing.fi" => :bing,
    "bing.pl" => :bing,

    # Yahoo
    "yahoo.com" => :yahoo,
    "www.yahoo.com" => :yahoo,
    "search.yahoo.com" => :yahoo,
    "yahoo.co.uk" => :yahoo,
    "yahoo.ca" => :yahoo,
    "yahoo.com.au" => :yahoo,
    "yahoo.de" => :yahoo,
    "yahoo.fr" => :yahoo,
    "yahoo.es" => :yahoo,
    "yahoo.it" => :yahoo,
    "yahoo.co.jp" => :yahoo,
    "yahoo.com.br" => :yahoo,
    "yahoo.com.mx" => :yahoo,
    "yahoo.nl" => :yahoo,
    "yahoo.se" => :yahoo,
    "yahoo.no" => :yahoo,
    "yahoo.dk" => :yahoo,
    "yahoo.fi" => :yahoo,

    # DuckDuckGo
    "duckduckgo.com" => :duckduckgo,
    "www.duckduckgo.com" => :duckduckgo,
    "ddg.gg" => :duckduckgo,

    # Brave Search
    "search.brave.com" => :brave,
    "brave.com" => :brave,

    # Yandex
    "yandex.ru" => :yandex,
    "yandex.com" => :yandex,
    "www.yandex.ru" => :yandex,
    "www.yandex.com" => :yandex,
    "yandex.by" => :yandex,
    "yandex.kz" => :yandex,
    "yandex.ua" => :yandex,
    "yandex.com.tr" => :yandex,

    # Baidu
    "baidu.com" => :baidu,
    "www.baidu.com" => :baidu,
    "m.baidu.com" => :baidu,

    # AI Search Platforms
    "chatgpt.com" => :chatgpt,
    "chat.openai.com" => :chatgpt,
    "claude.ai" => :claude,
    "gemini.google.com" => :gemini,
    "bard.google.com" => :gemini,
    "chat.deepseek.com" => :deepseek,
    "deepseek.com" => :deepseek,

    # Other Search Engines
    "ecosia.org" => :ecosia,
    "www.ecosia.org" => :ecosia,
    "startpage.com" => :startpage,
    "www.startpage.com" => :startpage,
    "searx.org" => :searx,
    "searx.me" => :searx,
    "searx.be" => :searx,
    "swisscows.com" => :swisscows,
    "www.swisscows.com" => :swisscows,
    "metager.org" => :metager,
    "www.metager.org" => :metager,
    "qwant.com" => :qwant,
    "www.qwant.com" => :qwant,
    "mojeek.com" => :mojeek,
    "www.mojeek.com" => :mojeek,
    "seznam.cz" => :seznam,
    "www.seznam.cz" => :seznam
  }

  # Mobile app referrers that indicate search traffic
  @mobile_app_referrers %{
    # Google mobile apps
    "android-app://com.google.android.googlequicksearchbox" => :google,
    "android-app://com.google.android.googlequicksearchbox/" => :google,
    "android-app://com.google.android.gm" => :google,
    "android-app://com.google.android.apps.searchlite" => :google,
    "android-app://com.chrome.beta" => :google,
    "android-app://com.chrome.canary" => :google,
    "android-app://com.chrome.dev" => :google,
    "android-app://com.android.chrome" => :google,
    "ios-app://585027354" => :google,
    "ios-app://535886823" => :google,

    # Microsoft/Bing mobile apps
    "android-app://com.microsoft.bing" => :bing,
    "android-app://com.microsoft.cortana" => :bing,
    "android-app://com.microsoft.emmx" => :bing,
    "ios-app://345323231" => :bing,
    "ios-app://1288723196" => :bing,

    # Yahoo mobile apps
    "android-app://com.yahoo.mobile.client.android.search" => :yahoo,
    "android-app://com.yahoo.mobile.client.android.mail" => :yahoo,
    "ios-app://577586159" => :yahoo,
    "ios-app://284910350" => :yahoo,

    # DuckDuckGo mobile apps
    "android-app://com.duckduckgo.mobile.android" => :duckduckgo,
    "ios-app://663592361" => :duckduckgo,

    # Brave mobile apps
    "android-app://com.brave.browser" => :brave,
    "ios-app://1052879175" => :brave,

    # Yandex mobile apps
    "android-app://ru.yandex.searchplugin" => :yandex,
    "android-app://com.yandex.browser" => :yandex,
    "ios-app://483693909" => :yandex,

    # Baidu mobile apps
    "android-app://com.baidu.searchbox" => :baidu,
    "android-app://com.baidu.BaiduMap" => :baidu,
    "ios-app://382201985" => :baidu,

    # AI Search mobile apps
    "android-app://com.openai.chatgpt" => :chatgpt,
    "ios-app://6448311069" => :chatgpt,
    "android-app://com.anthropic.claude" => :claude,
    "ios-app://6736252404" => :claude,

    # Other search engines mobile apps
    "android-app://org.ecosia.android" => :ecosia,
    "ios-app://670881887" => :ecosia,
    "android-app://com.startpage.search" => :startpage,
    "ios-app://1450889070" => :startpage,
    "android-app://com.swisscows.search" => :swisscows,
    "android-app://com.qwant.liberty" => :qwant,
    "ios-app://924470452" => :qwant
  }

  @domain_patterns [
    {~r/.*\.google\./, :google},
    {~r/.*\.bing\./, :bing},
    {~r/.*\.yahoo\./, :yahoo},
    {~r/.*\.yandex\./, :yandex},
    {~r/.*\.baidu\./, :baidu}
  ]

  @utm_source_mapping %{
    # Google variants
    "google" => :google,
    "google.com" => :google,
    "adwords" => :google,
    "google-ads" => :google,
    "googleads" => :google,
    "google_ads" => :google,
    "gads" => :google,
    "sem" => :google,

    # Microsoft/Bing variants
    "bing" => :bing,
    "bing.com" => :bing,
    "microsoft" => :bing,
    "microsoft-ads" => :bing,
    "bing-ads" => :bing,
    "bingads" => :bing,
    "msads" => :bing,

    # Yahoo variants
    "yahoo" => :yahoo,
    "yahoo.com" => :yahoo,
    "yahoo-ads" => :yahoo,
    "yahooads" => :yahoo,
    "yahoo_ads" => :yahoo,
    "yahoo_gemini" => :yahoo,

    # DuckDuckGo
    "duckduckgo" => :duckduckgo,
    "ddg" => :duckduckgo,

    # Brave
    "brave" => :brave,
    "brave-search" => :brave,

    # Yandex
    "yandex" => :yandex,
    "yandex.ru" => :yandex,
    "yandex-direct" => :yandex,
    "direct.yandex" => :yandex,

    # Baidu
    "baidu" => :baidu,
    "baidu.com" => :baidu,

    # AI Search platforms
    "chatgpt" => :chatgpt,
    "openai" => :chatgpt,
    "claude" => :claude,
    "anthropic" => :claude,
    "gemini" => :gemini,
    "bard" => :gemini,
    "deepseek" => :deepseek
  }

  # UTM medium values that typically indicate search advertising
  @search_mediums [
    "cpc",
    "ppc",
    "paid-search",
    "paid_search",
    "search",
    "sem",
    "adwords",
    "google-ads",
    "bing-ads",
    "yahoo-ads"
  ]

  # Platform-specific tracking parameters that indicate the source
  # HubSpot Ads parameters removed - handled by SocialPlatformDetector
  @platform_indicators %{
    # Google Ads indicators
    "gclid" => :google,
    "gclsrc" => :google,

    # Microsoft/Bing indicators
    "msclkid" => :bing
  }

  # Private helper functions

  defp parse_query_string(query_params) when is_binary(query_params) do
    try do
      clean_params = String.trim_leading(query_params, "?")
      param_map = URI.decode_query(clean_params)
      {:ok, param_map}
    rescue
      _ -> {:error, :invalid_query_string}
    end
  end

  defp parse_query_string(params) when is_list(params) do
    try do
      param_map = params_to_map(params)
      {:ok, param_map}
    rescue
      _ -> {:error, :invalid_params_format}
    end
  end

  defp parse_query_string(_), do: {:error, :invalid_params_type}

  defp params_to_map(params) do
    params
    |> Enum.reduce(%{}, fn
      %{"name" => name, "value" => value}, acc
      when is_binary(name) and is_binary(value) ->
        Map.put(acc, name, String.trim(value))

      _, acc ->
        acc
    end)
  end

  defp check_domain(domain) do
    case Map.get(@search_domains, domain) do
      nil -> check_pattern_matches(domain)
      platform -> platform
    end
  end

  defp check_pattern_matches(domain) do
    case Enum.find(@domain_patterns, fn {pattern, _platform} ->
           Regex.match?(pattern, domain)
         end) do
      {_pattern, platform} -> platform
      nil -> :none
    end
  end

  defp has_paid_search_indicators?(param_map) when is_map(param_map) do
    cond do
      has_platform_tracking_params?(param_map) -> true
      has_paid_search_utm?(param_map) -> true
      true -> false
    end
  end

  defp has_platform_tracking_params?(param_map) do
    Enum.any?(@platform_indicators, fn {param_name, _platform} ->
      Map.has_key?(param_map, param_name) and
        Map.get(param_map, param_name) != ""
    end)
  end

  defp has_paid_search_utm?(param_map) do
    utm_medium = Map.get(param_map, "utm_medium", "") |> String.downcase()
    utm_source = Map.get(param_map, "utm_source", "") |> String.downcase()

    # Only consider it paid search if:
    # 1. UTM medium indicates search advertising
    # 2. UTM source is a search platform (not social)
    utm_medium in @search_mediums and
      (Map.has_key?(@utm_source_mapping, utm_source) or
         has_search_source_keywords?(utm_source)) and
      not is_social_source?(utm_source)
  end

  defp has_search_source_keywords?(utm_source) do
    search_keywords = [
      "google",
      "adwords",
      "bing",
      "microsoft",
      "yahoo",
      "yandex",
      "baidu"
    ]

    Enum.any?(search_keywords, fn keyword ->
      String.contains?(utm_source, keyword)
    end)
  end

  defp is_social_source?(utm_source) do
    social_keywords = [
      "linkedin",
      "facebook",
      "instagram",
      "twitter",
      "tiktok",
      "pinterest",
      "snapchat",
      "reddit",
      # YouTube is often used for video ads, not search
      "youtube",
      "social"
    ]

    Enum.any?(social_keywords, fn keyword ->
      String.contains?(utm_source, keyword)
    end)
  end

  defp get_platform_from_params(param_map) do
    case detect_from_platform_indicators(param_map) do
      {:ok, true, platform} ->
        {:ok, platform}

      {:ok, false} ->
        case detect_from_utm_params(param_map) do
          {:ok, true, platform} -> {:ok, platform}
          {:ok, false} -> :not_found
        end
    end
  end

  def get_platform_from_referrer(referrer) do
    cond do
      # Check for mobile app referrers first
      is_mobile_app_referrer?(referrer) ->
        get_platform_from_mobile_app(referrer)

      # Then check regular web domains
      true ->
        case DomainExtractor.extract_base_domain(referrer) do
          {:ok, domain} ->
            case check_domain(domain) do
              :none -> :not_found
              platform -> {:ok, platform}
            end

          {:error, _} ->
            :not_found
        end
    end
  end

  defp is_mobile_app_referrer?(referrer) when is_binary(referrer) do
    String.starts_with?(referrer, "android-app://") or
      String.starts_with?(referrer, "ios-app://")
  end

  defp is_mobile_app_referrer?(_), do: false

  defp get_platform_from_mobile_app(referrer) do
    # Remove trailing slash for consistent matching
    clean_referrer = String.trim_trailing(referrer, "/")

    case Map.get(@mobile_app_referrers, clean_referrer) do
      nil ->
        # Try with trailing slash if not found
        case Map.get(@mobile_app_referrers, clean_referrer <> "/") do
          nil -> :not_found
          platform -> {:ok, platform}
        end

      platform ->
        {:ok, platform}
    end
  end

  defp detect_from_platform_indicators(param_map) do
    platform_param =
      Enum.find_value(@platform_indicators, fn {param_name, platform} ->
        if Map.has_key?(param_map, param_name), do: platform, else: nil
      end)

    case platform_param do
      nil -> {:ok, false}
      platform -> {:ok, true, platform}
    end
  end

  defp detect_from_utm_params(param_map) do
    utm_source = Map.get(param_map, "utm_source", "") |> String.downcase()
    utm_medium = Map.get(param_map, "utm_medium", "") |> String.downcase()

    cond do
      utm_medium not in @search_mediums ->
        {:ok, false}

      Map.has_key?(@utm_source_mapping, utm_source) ->
        platform = Map.get(@utm_source_mapping, utm_source)
        {:ok, true, platform}

      String.contains?(utm_source, "google") or
          String.contains?(utm_source, "adwords") ->
        {:ok, true, :google}

      String.contains?(utm_source, "bing") or
          String.contains?(utm_source, "microsoft") ->
        {:ok, true, :bing}

      String.contains?(utm_source, "yahoo") ->
        {:ok, true, :yahoo}

      String.contains?(utm_source, "yandex") ->
        {:ok, true, :yandex}

      String.contains?(utm_source, "baidu") ->
        {:ok, true, :baidu}

      true ->
        {:ok, false}
    end
  end
end
