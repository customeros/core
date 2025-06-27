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
    Application.get_env(:core, :bot_detector_max_requests_per_minute, 10000)
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
  Gets the list of automation tools to detect.
  """
  def automation_tools do
    Application.get_env(:core, :bot_detector_automation_tools, [
      "selenium",
      "webdriver",
      "phantomjs",
      "headless",
      "playwright",
      "cypress",
      "puppeteer",
      "automation",
      "testcafe",
      "nightwatch",
      "protractor",
      "cucumber",
      "behat",
      "robot",
      "automated",
      "script",
      "crawler",
      "scraper",
      "spider"
    ])
  end

  @doc """
  Gets the list of suspicious automation flags.
  """
  def suspicious_automation_flags do
    Application.get_env(:core, :bot_detector_suspicious_automation_flags, [
      "headless",
      "no-sandbox",
      "disable-dev-shm-usage",
      "disable-gpu",
      "disable-web-security",
      "disable-features",
      "disable-extensions",
      "disable-plugins",
      "disable-images",
      "disable-javascript",
      "disable-css",
      "disable-cookies",
      "disable-local-storage",
      "disable-session-storage",
      "disable-indexeddb",
      "disable-websockets",
      "disable-notifications",
      "disable-popup-blocking",
      "disable-background-timer-throttling",
      "disable-backgrounding-occluded-windows",
      "disable-renderer-backgrounding",
      "disable-ipc-flooding-protection",
      "disable-hang-monitor",
      "disable-prompt-on-repost",
      "disable-domain-reliability",
      "disable-component-extensions-with-background-pages",
      "disable-default-apps",
      "disable-sync",
      "disable-translate",
      "disable-logging",
      "disable-background-networking",
      "disable-client-side-phishing-detection",
      "disable-component-update"
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
end
