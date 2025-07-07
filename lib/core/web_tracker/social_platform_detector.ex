defmodule Core.WebTracker.SocialPlatformDetector do
  @moduledoc """
  Detects social platforms and distinguishes between paid and organic social traffic.

  This module analyzes referrer URLs, query parameters, and user agent strings to 
  identify social media platforms (Facebook, Instagram, Twitter, LinkedIn, etc.) 
  and determine whether traffic comes from paid advertising campaigns or organic 
  social media posts.
  """

  alias Core.Utils.DomainExtractor

  @doc """
  Checks if the referrer and query params indicate paid social traffic.

  Returns true if query params contain paid social indicators.
  """
  def paid_social?(query_params) do
    case parse_query_string(query_params) do
      {:ok, param_map} ->
        has_paid_social_indicators?(param_map)

      {:error, _} ->
        false
    end
  end

  @doc """
  Checks if the referrer indicates organic social traffic.

  Returns true if referrer is from a social platform AND no paid indicators.
  """
  def organic_social?(referrer, query_params) do
    case get_platform_from_referrer(referrer) do
      {:ok, _platform} ->
        case parse_query_string(query_params) do
          {:ok, param_map} ->
            not has_paid_social_indicators?(param_map)

          {:error, _} ->
            true
        end

      :not_found ->
        false
    end
  end

  @doc """
  Gets the social platform from referrer, query params, or user agent.

  Returns {:ok, :facebook} or :not_found
  """
  def get_platform(referrer, query_params, user_agent \\ nil) do
    case parse_query_string(query_params) do
      {:ok, param_map} ->
        case get_platform_from_params(param_map) do
          {:ok, platform} ->
            {:ok, platform}

          :not_found ->
            case get_platform_from_referrer(referrer) do
              {:ok, platform} ->
                {:ok, platform}

              :not_found ->
                get_platform_from_user_agent(user_agent)
            end
        end

      {:error, _} ->
        case get_platform_from_referrer(referrer) do
          {:ok, platform} ->
            {:ok, platform}

          :not_found ->
            get_platform_from_user_agent(user_agent)
        end
    end
  end

  # In-app browser user agent patterns
  @in_app_browser_patterns [
    # Facebook/Meta in-app browsers
    "fban",
    "fbav",
    "fbsv",
    "fbid",
    "instagram",
    "messenger",

    # Twitter/X in-app browser
    "twitterandroid",
    "twitteriphone",
    "twitter for",

    # LinkedIn in-app browser
    "linkedinapp",
    "linkedin",

    # TikTok in-app browser
    "tiktok",
    "musical_ly",

    # Pinterest in-app browser
    "pinterest",

    # Snapchat in-app browser
    "snapchat",

    # Other social in-app browsers
    "line",
    "whatsapp",
    "telegram",
    "discord",
    "reddit",
    "tumblr"
  ]

  @doc """
  Detects if traffic is from a social media in-app browser.

  Returns true if user agent indicates in-app browser from social platforms.
  """
  def in_app_browser?(user_agent) when is_binary(user_agent) do
    user_agent_lower = String.downcase(user_agent)

    Enum.any?(@in_app_browser_patterns, fn pattern ->
      String.contains?(user_agent_lower, pattern)
    end)
  end

  def in_app_browser?(_), do: false

  @social_domains %{
    # Facebook/Meta
    "facebook.com" => :facebook,
    "www.facebook.com" => :facebook,
    "m.facebook.com" => :facebook,
    "mobile.facebook.com" => :facebook,
    "fb.com" => :facebook,
    "fb.me" => :facebook,
    "messenger.com" => :facebook,

    # Instagram
    "instagram.com" => :instagram,
    "www.instagram.com" => :instagram,
    "m.instagram.com" => :instagram,
    "instagr.am" => :instagram,

    # Twitter/X
    "twitter.com" => :twitter,
    "www.twitter.com" => :twitter,
    "m.twitter.com" => :twitter,
    "mobile.twitter.com" => :twitter,
    "t.co" => :twitter,
    "x.com" => :twitter,
    "www.x.com" => :twitter,

    # LinkedIn
    "linkedin.com" => :linkedin,
    "www.linkedin.com" => :linkedin,
    "m.linkedin.com" => :linkedin,
    "lnkd.in" => :linkedin,

    # YouTube
    "youtube.com" => :youtube,
    "www.youtube.com" => :youtube,
    "m.youtube.com" => :youtube,
    "youtu.be" => :youtube,

    # TikTok
    "tiktok.com" => :tiktok,
    "www.tiktok.com" => :tiktok,
    "m.tiktok.com" => :tiktok,
    "vm.tiktok.com" => :tiktok,

    # Snapchat
    "snapchat.com" => :snapchat,
    "www.snapchat.com" => :snapchat,
    "snap.com" => :snapchat,

    # Pinterest
    "pinterest.com" => :pinterest,
    "www.pinterest.com" => :pinterest,
    "m.pinterest.com" => :pinterest,
    "pin.it" => :pinterest,

    # Reddit
    "reddit.com" => :reddit,
    "www.reddit.com" => :reddit,
    "m.reddit.com" => :reddit,
    "old.reddit.com" => :reddit,
    "redd.it" => :reddit,

    # Discord
    "discord.com" => :discord,
    "www.discord.com" => :discord,
    "discord.gg" => :discord,
    "discordapp.com" => :discord,

    # Telegram
    "telegram.org" => :telegram,
    "telegram.me" => :telegram,
    "t.me" => :telegram,

    # WhatsApp
    "whatsapp.com" => :whatsapp,
    "www.whatsapp.com" => :whatsapp,
    "wa.me" => :whatsapp,

    # Twitch
    "twitch.tv" => :twitch,
    "www.twitch.tv" => :twitch,
    "m.twitch.tv" => :twitch,

    # Clubhouse
    "clubhouse.com" => :clubhouse,
    "www.clubhouse.com" => :clubhouse,

    # Mastodon (common instances)
    "mastodon.social" => :mastodon,
    "mastodon.online" => :mastodon,
    "mastodon.world" => :mastodon,
    "mas.to" => :mastodon,

    # Other platforms
    "vk.com" => :vkontakte,
    "www.vk.com" => :vkontakte,
    "weibo.com" => :weibo,
    "www.weibo.com" => :weibo,
    "line.me" => :line,
    "vimeo.com" => :vimeo,
    "www.vimeo.com" => :vimeo,
    "quora.com" => :quora,
    "www.quora.com" => :quora,
    "medium.com" => :medium,
    "tumblr.com" => :tumblr,
    "www.tumblr.com" => :tumblr
  }

  @domain_patterns [
    {~r/.*\.facebook\./, :facebook},
    {~r/.*\.instagram\./, :instagram},
    {~r/.*\.twitter\./, :twitter},
    {~r/.*\.linkedin\./, :linkedin},
    {~r/.*\.youtube\./, :youtube},
    {~r/.*\.tiktok\./, :tiktok},
    {~r/.*\.pinterest\./, :pinterest},
    {~r/.*\.reddit\./, :reddit},
    {~r/.*\.discord\./, :discord},
    {~r/.*\.snapchat\./, :snapchat},
    {~r/.*\.twitch\./, :twitch},
    {~r/.*\.vk\./, :vkontakte},
    {~r/.*\.weibo\./, :weibo},
    {~r/.*\.tumblr\./, :tumblr},
    {~r/.*\.mastodon\./, :mastodon}
  ]

  @utm_source_mapping %{
    # Facebook/Meta variants
    "facebook" => :facebook,
    "facebook.com" => :facebook,
    "fb" => :facebook,
    "meta" => :facebook,
    "facebook-ads" => :facebook,
    "facebook_ads" => :facebook,
    "facebookads" => :facebook,
    "ig" => :instagram,
    "instagram" => :instagram,
    "instagram.com" => :instagram,
    "instagram-ads" => :instagram,
    "instagram_ads" => :instagram,
    "instagramads" => :instagram,

    # Twitter/X variants
    "twitter" => :twitter,
    "twitter.com" => :twitter,
    "twitter-ads" => :twitter,
    "twitter_ads" => :twitter,
    "twitterads" => :twitter,
    "x" => :twitter,
    "x.com" => :twitter,

    # LinkedIn variants
    "linkedin" => :linkedin,
    "linkedin.com" => :linkedin,
    "linkedin-ads" => :linkedin,
    "linkedin_ads" => :linkedin,
    "linkedinads" => :linkedin,

    # YouTube variants
    "youtube" => :youtube,
    "youtube.com" => :youtube,
    "youtube-ads" => :youtube,
    "youtube_ads" => :youtube,
    "youtubeads" => :youtube,

    # TikTok variants
    "tiktok" => :tiktok,
    "tiktok.com" => :tiktok,
    "tiktok-ads" => :tiktok,
    "tiktok_ads" => :tiktok,
    "tiktokads" => :tiktok,

    # Pinterest variants
    "pinterest" => :pinterest,
    "pinterest.com" => :pinterest,
    "pinterest-ads" => :pinterest,
    "pinterest_ads" => :pinterest,
    "pinterestads" => :pinterest,

    # Snapchat variants
    "snapchat" => :snapchat,
    "snapchat.com" => :snapchat,
    "snapchat-ads" => :snapchat,
    "snapchat_ads" => :snapchat,
    "snapchatads" => :snapchat,

    # Reddit variants
    "reddit" => :reddit,
    "reddit.com" => :reddit,
    "reddit-ads" => :reddit,
    "reddit_ads" => :reddit,
    "redditads" => :reddit,

    # Discord variants
    "discord" => :discord,
    "discord.com" => :discord,

    # Other platforms
    "telegram" => :telegram,
    "whatsapp" => :whatsapp,
    "twitch" => :twitch,
    "vk" => :vkontakte,
    "vkontakte" => :vkontakte,
    "weibo" => :weibo,
    "line" => :line,
    "vimeo" => :vimeo,
    "quora" => :quora,
    "medium" => :medium,
    "tumblr" => :tumblr,
    "mastodon" => :mastodon,
    "clubhouse" => :clubhouse
  }

  # UTM medium values that typically indicate social advertising
  @social_mediums [
    "social",
    "social-media",
    "social_media",
    "social-paid",
    "social_paid",
    "paidsocial",
    "paid-social",
    "paid_social",
    "cpc",
    "ppc",
    "paid",
    "display",
    "banner",
    "native",
    "video",
    "social-video",
    "social_video"
  ]

  # Platform-specific tracking parameters that indicate paid social
  @platform_indicators %{
    # Facebook/Meta indicators
    "fbclid" => :facebook,
    "fb_source" => :facebook,
    "fb_ref" => :facebook,
    "igshid" => :instagram,
    "ig_source" => :instagram,

    # Twitter/X indicators
    "twclid" => :twitter,
    "twitter_source" => :twitter,
    "ref_src" => :twitter,
    "ref_url" => :twitter,

    # LinkedIn indicators
    "li_source" => :linkedin,
    "linkedin_source" => :linkedin,
    "trk" => :linkedin,

    # YouTube indicators
    "yt_source" => :youtube,
    "youtube_source" => :youtube,

    # TikTok indicators
    "tt_source" => :tiktok,
    "tiktok_source" => :tiktok,
    "ttclid" => :tiktok,

    # Pinterest indicators
    "pin_source" => :pinterest,
    "pinterest_source" => :pinterest,

    # Snapchat indicators
    "snap_source" => :snapchat,
    "snapchat_source" => :snapchat,
    "sc_source" => :snapchat,

    # Reddit indicators
    "reddit_source" => :reddit,
    "rd_source" => :reddit
  }

  # Paid social campaign indicators in URLs
  @paid_campaign_indicators [
    "ad_id",
    "ad_name",
    "campaign_id",
    "campaign_name",
    "adset_id",
    "adset_name",
    "creative_id",
    "placement_id",
    "ad_type",
    "sponsor",
    "promoted",
    "boost_id",
    "boost_post_id"
  ]

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
    case Map.get(@social_domains, domain) do
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

  defp has_paid_social_indicators?(param_map) when is_map(param_map) do
    cond do
      has_platform_tracking_params?(param_map) -> true
      has_paid_social_utm?(param_map) -> true
      has_paid_campaign_indicators?(param_map) -> true
      true -> false
    end
  end

  defp has_platform_tracking_params?(param_map) do
    Enum.any?(@platform_indicators, fn {param_name, _platform} ->
      Map.has_key?(param_map, param_name) and
        Map.get(param_map, param_name) != ""
    end)
  end

  defp has_paid_social_utm?(param_map) do
    utm_medium = Map.get(param_map, "utm_medium", "") |> String.downcase()
    utm_source = Map.get(param_map, "utm_source", "") |> String.downcase()

    utm_medium in @social_mediums and
      (Map.has_key?(@utm_source_mapping, utm_source) or
         has_social_source_keywords?(utm_source))
  end

  defp has_paid_campaign_indicators?(param_map) do
    Enum.any?(@paid_campaign_indicators, fn indicator ->
      Map.has_key?(param_map, indicator) and
        Map.get(param_map, indicator) != ""
    end)
  end

  defp has_social_source_keywords?(utm_source) do
    social_keywords = [
      "facebook",
      "instagram",
      "twitter",
      "linkedin",
      "youtube",
      "tiktok",
      "pinterest",
      "snapchat",
      "reddit",
      "discord",
      "telegram",
      "whatsapp",
      "social"
    ]

    Enum.any?(social_keywords, fn keyword ->
      String.contains?(utm_source, keyword)
    end)
  end

  defp get_platform_from_params(param_map) do
    case detect_from_platform_indicators(param_map) do
      {:ok, platform} ->
        {:ok, platform}

      :not_found ->
        case detect_from_utm_params(param_map) do
          {:ok, platform} -> {:ok, platform}
          :not_found -> :not_found
        end
    end
  end

  defp get_platform_from_referrer(referrer) do
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

  defp get_platform_from_user_agent(nil), do: :not_found
  defp get_platform_from_user_agent(""), do: :not_found

  defp get_platform_from_user_agent(user_agent) when is_binary(user_agent) do
    user_agent_lower = String.downcase(user_agent)

    platform =
      cond do
        String.contains?(user_agent_lower, "fban") or
          String.contains?(user_agent_lower, "fbav") or
            String.contains?(user_agent_lower, "fbsv") ->
          :facebook

        String.contains?(user_agent_lower, "instagram") ->
          :instagram

        String.contains?(user_agent_lower, "twitterandroid") or
          String.contains?(user_agent_lower, "twitteriphone") or
            String.contains?(user_agent_lower, "twitter for") ->
          :twitter

        String.contains?(user_agent_lower, "linkedinapp") or
            String.contains?(user_agent_lower, "linkedin") ->
          :linkedin

        String.contains?(user_agent_lower, "tiktok") or
            String.contains?(user_agent_lower, "musical_ly") ->
          :tiktok

        String.contains?(user_agent_lower, "pinterest") ->
          :pinterest

        String.contains?(user_agent_lower, "snapchat") ->
          :snapchat

        String.contains?(user_agent_lower, "line") ->
          :line

        String.contains?(user_agent_lower, "whatsapp") ->
          :whatsapp

        String.contains?(user_agent_lower, "telegram") ->
          :telegram

        String.contains?(user_agent_lower, "discord") ->
          :discord

        String.contains?(user_agent_lower, "reddit") ->
          :reddit

        String.contains?(user_agent_lower, "tumblr") ->
          :tumblr

        true ->
          nil
      end

    case platform do
      nil -> :not_found
      platform -> {:ok, platform}
    end
  end

  defp detect_from_platform_indicators(param_map) do
    platform_param =
      Enum.find_value(@platform_indicators, fn {param_name, platform} ->
        if Map.has_key?(param_map, param_name), do: platform, else: nil
      end)

    case platform_param do
      nil -> :not_found
      platform -> {:ok, platform}
    end
  end

  defp detect_from_utm_params(param_map) do
    utm_source = Map.get(param_map, "utm_source", "") |> String.downcase()
    utm_medium = Map.get(param_map, "utm_medium", "") |> String.downcase()

    cond do
      utm_medium not in @social_mediums ->
        :not_found

      Map.has_key?(@utm_source_mapping, utm_source) ->
        platform = Map.get(@utm_source_mapping, utm_source)
        {:ok, platform}

      String.contains?(utm_source, "facebook") or
          String.contains?(utm_source, "fb") ->
        {:ok, :facebook}

      String.contains?(utm_source, "instagram") or
          String.contains?(utm_source, "ig") ->
        {:ok, :instagram}

      String.contains?(utm_source, "twitter") or
          String.contains?(utm_source, "x.com") ->
        {:ok, :twitter}

      String.contains?(utm_source, "linkedin") ->
        {:ok, :linkedin}

      String.contains?(utm_source, "youtube") ->
        {:ok, :youtube}

      String.contains?(utm_source, "tiktok") ->
        {:ok, :tiktok}

      String.contains?(utm_source, "pinterest") ->
        {:ok, :pinterest}

      String.contains?(utm_source, "snapchat") ->
        {:ok, :snapchat}

      String.contains?(utm_source, "reddit") ->
        {:ok, :reddit}

      String.contains?(utm_source, "discord") ->
        {:ok, :discord}

      String.contains?(utm_source, "telegram") ->
        {:ok, :telegram}

      String.contains?(utm_source, "whatsapp") ->
        {:ok, :whatsapp}

      true ->
        :not_found
    end
  end
end
