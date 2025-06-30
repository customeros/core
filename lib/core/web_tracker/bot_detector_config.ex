defmodule Core.WebTracker.BotDetectorConfig do
  @moduledoc """
  Configuration module for the bot detector.
  Provides centralized configuration management for bot detection parameters.
  """

  @doc """
  Gets the cache TTL in seconds.
  """
  def cache_ttl do
    # 5 minutes default
    Application.get_env(:core, :bot_detector_cache_ttl, 300)
  end

  @doc """
  Gets the maximum requests per minute for rate limiting.
  """
  def max_requests_per_minute do
    Application.get_env(:core, :bot_detector_max_requests_per_minute, 100)
  end

  @doc """
  Gets the confidence threshold for bot detection.
  """
  def confidence_threshold do
    Application.get_env(:core, :bot_detector_confidence_threshold, 0.7)
  end

  @doc """
  Gets the weights for different detection signals.
  """
  def signal_weights do
    Application.get_env(:core, :bot_detector_signal_weights, %{
      user_agent: 0.6,
      ip_address: 0.3,
      behavioral: 0.1
    })
  end

  @doc """
  Gets the list of whitelisted user agents that should never be flagged as bots.
  """
  def whitelisted_user_agents do
    Application.get_env(:core, :bot_detector_whitelisted_user_agents, [])
  end

  @doc """
  Gets the list of blacklisted user agents that should always be flagged as bots.
  """
  def blacklisted_user_agents do
    Application.get_env(:core, :bot_detector_blacklisted_user_agents, [])
  end

  @doc """
  Gets the list of whitelisted IP addresses that should never be flagged as bots.
  """
  def whitelisted_ips do
    Application.get_env(:core, :bot_detector_whitelisted_ips, [])
  end

  @doc """
  Gets the list of blacklisted IP addresses that should always be flagged as bots.
  """
  def blacklisted_ips do
    Application.get_env(:core, :bot_detector_blacklisted_ips, [])
  end

  @doc """
  Gets whether to enable caching.
  """
  def enable_caching do
    Application.get_env(:core, :bot_detector_enable_caching, true)
  end

  @doc """
  Gets whether to enable rate limiting.
  """
  def enable_rate_limiting do
    Application.get_env(:core, :bot_detector_enable_rate_limiting, true)
  end

  @doc """
  Gets the cleanup interval in milliseconds.
  """
  def cleanup_interval do
    # 1 minute default
    Application.get_env(:core, :bot_detector_cleanup_interval, 60_000)
  end

  @doc """
  Gets whether to enable detailed logging.
  """
  def enable_detailed_logging do
    Application.get_env(:core, :bot_detector_enable_detailed_logging, false)
  end

  @doc """
  Gets the list of trusted search engine bots.
  """
  def trusted_search_engines do
    Application.get_env(:core, :bot_detector_trusted_search_engines, [
      "googlebot",
      "bingbot",
      "slurp",
      "duckduckbot"
    ])
  end

  @doc """
  Gets the list of trusted social media bots.
  """
  def trusted_social_media do
    Application.get_env(:core, :bot_detector_trusted_social_media, [
      "facebookexternalhit",
      "twitterbot",
      "linkedinbot",
      "whatsapp",
      "telegrambot",
      "discordbot",
      "slackbot"
    ])
  end

  @doc """
  Gets the list of automation tool regex patterns to detect.
  """
  def automation_patterns do
    Application.get_env(:core, :bot_detector_automation_patterns, [
      ~r/selenium/i,
      ~r/webdriver/i,
      ~r/phantomjs/i,
      ~r/headless/i,
      ~r/playwright/i,
      ~r/cypress/i,
      ~r/puppeteer/i,
      ~r/automation/i,
      ~r/testcafe/i,
      ~r/nightwatch/i,
      ~r/protractor/i,
      ~r/cucumber/i,
      ~r/behat/i,
      ~r/robot/i,
      ~r/automated/i,
      ~r/script/i
    ])
  end

  @doc """
  Gets the list of browser engine regex patterns to detect.
  """
  def browser_engine_patterns do
    Application.get_env(:core, :bot_detector_browser_engine_patterns, [
      ~r/webkit/i,
      ~r/gecko/i,
      ~r/trident/i,
      ~r/edgehtml/i,
      ~r/blink/i
    ])
  end

  @doc """
  Gets the list of suspicious automation flags.
  """
  def suspicious_automation_flags do
    Application.get_env(:core, :bot_detector_suspicious_automation_flags, [
      ~r/headless/i,
      ~r/no-sandbox/i,
      ~r/disable-dev-shm-usage/i,
      ~r/disable-gpu/i,
      ~r/disable-web-security/i,
      ~r/disable-features/i,
      ~r/disable-extensions/i,
      ~r/disable-plugins/i,
      ~r/disable-images/i,
      ~r/disable-javascript/i,
      ~r/disable-css/i,
      ~r/disable-cookies/i,
      ~r/disable-local-storage/i,
      ~r/disable-session-storage/i,
      ~r/disable-indexeddb/i,
      ~r/disable-websockets/i,
      ~r/disable-notifications/i,
      ~r/disable-popup-blocking/i,
      ~r/disable-background-timer-throttling/i,
      ~r/disable-backgrounding-occluded-windows/i,
      ~r/disable-renderer-backgrounding/i,
      ~r/disable-ipc-flooding-protection/i,
      ~r/disable-hang-monitor/i,
      ~r/disable-prompt-on-repost/i,
      ~r/disable-domain-reliability/i,
      ~r/disable-component-extensions-with-background-pages/i,
      ~r/disable-default-apps/i,
      ~r/disable-sync/i,
      ~r/disable-translate/i,
      ~r/disable-logging/i,
      ~r/disable-background-networking/i,
      ~r/disable-client-side-phishing-detection/i,
      ~r/disable-component-update/i
    ])
  end

  @doc """
  Gets the list of datacenter IP patterns.
  """
  def datacenter_ip_patterns do
    Application.get_env(:core, :bot_detector_datacenter_ip_patterns, [
      # Google DNS
      ~r/^8\.8\.8\.8$/i,
      # Cloudflare DNS
      ~r/^1\.1\.1\.1$/i,
      # OpenDNS
      ~r/^208\.67\.222\.222$/i,
      # Quad9 DNS
      ~r/^9\.9\.9\.9$/i
    ])
  end

  @doc """
  Gets the list of suspicious IP ranges.
  """
  def suspicious_ip_ranges do
    Application.get_env(:core, :bot_detector_suspicious_ip_ranges, [
      # Private network
      ~r/^192\.168\./i,
      # Private network
      ~r/^10\./i,
      # Private network
      ~r/^172\.(1[6-9]|2[0-9]|3[0-1])\./i,
      # Localhost
      ~r/^127\.0\.0\.1$/i,
      # Invalid IP
      ~r/^0\.0\.0\.0$/i,
      # IPv6 localhost
      ~r/^::1$/i
    ])
  end

  @doc """
  Gets the list of suspicious header regex patterns to detect.
  """
  def suspicious_header_patterns do
    Application.get_env(:core, :bot_detector_suspicious_header_patterns, [
      # Empty user agent
      ~r/^$/i,
      # Very long alphanumeric
      ~r/^[a-z0-9]{16,}$/i,
      # Very long letter string
      ~r/^[a-z]{20,}$/i,
      # Very long number string
      ~r/^[0-9]{20,}$/i,
      # Only alphanumeric (no spaces, punctuation)
      ~r/^[a-z0-9]+$/i,
      # Only letters
      ~r/^[a-z]+$/i,
      # Only numbers
      ~r/^[0-9]+$/i,
      # Long alphanumeric without browser info
      ~r/^[a-z0-9]{8,}$/i
    ])
  end

  @doc """
  Gets the list of browser regex patterns to detect (negative signals).
  """
  def browser_patterns do
    Application.get_env(:core, :bot_detector_browser_patterns, [
      ~r/chrome/i,
      ~r/firefox/i,
      ~r/safari/i,
      ~r/edge/i,
      ~r/opera/i,
      ~r/ie/i,
      ~r/trident/i,
      ~r/webkit/i,
      ~r/gecko/i
    ])
  end

  @doc """
  Gets the list of strong bot regex patterns to detect (excluding trusted search engines).
  """
  def strong_bot_patterns do
    Application.get_env(:core, :bot_detector_strong_bot_patterns, [
      ~r/facebookexternalhit/i,
      ~r/twitterbot/i,
      ~r/linkedinbot/i,
      ~r/whatsapp/i,
      ~r/telegrambot/i,
      ~r/skypeuripreview/i,
      ~r/discordbot/i,
      ~r/slackbot/i
    ])
  end

  @doc """
  Gets the list of medium bot regex patterns to detect.
  """
  def medium_bot_patterns do
    Application.get_env(:core, :bot_detector_medium_bot_patterns, [
      ~r/bot/i,
      ~r/crawler/i,
      ~r/spider/i,
      ~r/robot/i,
      ~r/scraper/i,
      ~r/curl/i,
      ~r/wget/i,
      ~r/httpclient/i,
      ~r/requests/i,
      ~r/urllib/i
    ])
  end

  @doc """
  Gets the list of suspicious user agent regex patterns to detect.
  """
  def suspicious_patterns do
    Application.get_env(:core, :bot_detector_suspicious_patterns, [
      # Long alphanumeric string
      ~r/^[a-z0-9]{8,}$/i,
      # Long letter string
      ~r/^[a-z]{10,}$/i,
      # Long number string
      ~r/^[0-9]{10,}$/i,
      # Only alphanumeric (no spaces, punctuation)
      ~r/^[a-z0-9]+$/i,
      # Only letters
      ~r/^[a-z]+$/i,
      # Only numbers
      ~r/^[0-9]+$/i
    ])
  end
end
