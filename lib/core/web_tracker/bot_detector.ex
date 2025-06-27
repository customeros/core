defmodule Core.WebTracker.BotDetector do
  @moduledoc """
  Bot detection module that implements sophisticated bot detection logic.
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Core.WebTracker.BotDetectorConfig

  @doc """
  Detects if a request is from a bot using our custom detection logic.
  Returns {:ok, result} or {:error, reason}.
  The result is a map with the following keys:
  - bot: boolean indicating if the request is from a bot
  - confidence: float between 0 and 1 indicating the confidence in the detection
  - signals: list of signals that contributed to the detection
  - timestamp: datetime of the detection
  - source: string indicating the source of the detection
  - request_id: string indicating the request ID
  """
  @spec detect_bot(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def detect_bot(user_agent, ip, origin, referrer) do
    OpenTelemetry.Tracer.with_span "bot_detector.detect_bot" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.user_agent", user_agent},
        {"param.ip", ip},
        {"param.origin", origin},
        {"param.referrer", referrer}
      ])

      # Check rate limiting if enabled
      case check_rate_limit_if_enabled(ip) do
        :ok ->
          # Check cache first if enabled
          cache_key = generate_cache_key(user_agent, ip, origin)

          case get_cached_result_if_enabled(cache_key) do
            {:ok, cached_result} ->
              if BotDetectorConfig.enable_detailed_logging() do
                Logger.debug("Bot detection result served from cache",
                  cache_key: cache_key
                )
              end

              {:ok, cached_result}

            :not_found ->
              # Perform bot detection
              {:ok, result} = perform_bot_detection(user_agent, ip, origin)

              # Cache the result if enabled
              cache_result_if_enabled(cache_key, result)
              {:ok, result}
          end

        {:error, :rate_limited} ->
          Logger.warning("Rate limit exceeded for IP", ip: ip)
          {:error, "rate_limit_exceeded"}
      end
    end
  end

  @spec perform_bot_detection(String.t(), String.t(), String.t()) ::
          {:ok, map()}
  defp perform_bot_detection(user_agent, ip, origin) do
    # Create detection request payload
    detection_request = %{
      userAgent: user_agent,
      ip: ip,
      origin: origin,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Execute detection logic (always returns {:ok, result})
    {:ok, detection_result} = execute_detection_logic(detection_request)

    # Transform to expected format
    result = %{
      bot: detection_result.bot,
      confidence: detection_result.confidence || 0.8,
      signals: detection_result.signals || [],
      timestamp:
        detection_result.timestamp ||
          DateTime.utc_now() |> DateTime.to_iso8601(),
      source: "custom_bot_detection",
      request_id: generate_request_id()
    }

    {:ok, result}
  end

  @spec execute_detection_logic(map()) :: {:ok, map()}
  defp execute_detection_logic(request) do
    user_agent = request.userAgent || ""
    ip = request.ip || ""

    # Enhanced bot detection using our custom logic
    {is_bot, confidence, signals} = analyze_with_custom_logic(user_agent, ip)

    {:ok,
     %{
       bot: is_bot,
       confidence: confidence,
       signals: signals,
       timestamp: request.timestamp
     }}
  end

  @spec analyze_with_custom_logic(String.t(), String.t()) ::
          {boolean(), float(), list()}
  defp analyze_with_custom_logic(user_agent, ip) do
    signals = []
    confidence = 0.0
    weights = BotDetectorConfig.signal_weights()

    # Signal 1: User agent analysis (most important)
    {ua_signals, ua_score} = analyze_user_agent_advanced(user_agent)
    signals = signals ++ ua_signals
    confidence = confidence + ua_score * weights.user_agent

    # Signal 2: IP analysis
    {ip_signals, ip_score} = analyze_ip_address(ip)
    signals = signals ++ ip_signals
    confidence = confidence + ip_score * weights.ip_address

    # Signal 3: Behavioral patterns
    {behavior_signals, behavior_score} =
      analyze_behavioral_patterns(user_agent, ip)

    signals = signals ++ behavior_signals
    confidence = confidence + behavior_score * weights.behavioral

    # Check if any signal has weight 1.0 (high confidence bot detection)
    has_high_confidence_signal = Enum.any?(signals, &(&1.weight == 1.0))

    # Determine if it's a bot based on confidence threshold OR high confidence signal
    is_bot =
      has_high_confidence_signal or
        confidence > BotDetectorConfig.confidence_threshold()

    {is_bot, min(confidence, 1.0), signals}
  end

  @spec analyze_user_agent_advanced(String.t()) :: {list(), float()}
  defp analyze_user_agent_advanced(user_agent)
       when is_binary(user_agent) and user_agent != "" do
    user_agent_lower = String.downcase(user_agent)

    # Check whitelisted user agents first
    case check_whitelisted_user_agent(user_agent_lower) do
      {:whitelisted, signals, score} ->
        {signals, score}

      :not_whitelisted ->
        # Check trusted search engines
        case check_trusted_search_engine(user_agent_lower) do
          {:trusted, signals, score} ->
            {signals, score}

          :not_trusted ->
            # Check trusted social media bots
            case check_trusted_social_media(user_agent_lower) do
              {:trusted, signals, score} ->
                {signals, score}

              :not_trusted ->
                # Check blacklisted user agents
                case check_blacklisted_user_agent(user_agent_lower) do
                  {:blacklisted, signals, score} ->
                    {signals, score}

                  :not_blacklisted ->
                    analyze_user_agent_patterns(user_agent_lower)
                end
            end
        end
    end
  end

  defp analyze_user_agent_advanced(_),
    do:
      {[
         %{
           type: "missing_user_agent",
           value: "No user agent provided",
           weight: 0.8
         }
       ], 0.8}

  defp check_whitelisted_user_agent(user_agent_lower) do
    whitelisted_patterns =
      BotDetectorConfig.whitelisted_user_agents()
      |> Enum.map(&String.downcase/1)

    if Enum.any?(whitelisted_patterns, &String.contains?(user_agent_lower, &1)) do
      {:whitelisted,
       [
         %{
           type: "whitelisted_user_agent",
           value: "User agent is whitelisted",
           weight: -1.0
         }
       ], 0.0}
    else
      :not_whitelisted
    end
  end

  defp check_trusted_search_engine(user_agent_lower) do
    trusted_search_patterns =
      BotDetectorConfig.trusted_search_engines()
      |> Enum.map(&String.downcase/1)

    if Enum.any?(
         trusted_search_patterns,
         &String.contains?(user_agent_lower, &1)
       ) do
      {:trusted,
       [
         %{
           type: "trusted_search_engine",
           value: "User agent is a trusted search engine bot",
           weight: -1.0
         }
       ], 0.0}
    else
      :not_trusted
    end
  end

  defp check_trusted_social_media(user_agent_lower) do
    trusted_social_patterns =
      BotDetectorConfig.trusted_social_media()
      |> Enum.map(&String.downcase/1)

    if Enum.any?(
         trusted_social_patterns,
         &String.contains?(user_agent_lower, &1)
       ) do
      {:trusted,
       [
         %{
           type: "trusted_social_media",
           value: "User agent is a trusted social media bot",
           weight: -1.0
         }
       ], 0.0}
    else
      :not_trusted
    end
  end

  defp check_blacklisted_user_agent(user_agent_lower) do
    blacklisted_patterns =
      BotDetectorConfig.blacklisted_user_agents()
      |> Enum.map(&String.downcase/1)

    if Enum.any?(
         blacklisted_patterns,
         &String.contains?(user_agent_lower, &1)
       ) do
      {:blacklisted,
       [
         %{
           type: "blacklisted_user_agent",
           value: "User agent is blacklisted",
           weight: 1.0
         }
       ], 1.0}
    else
      :not_blacklisted
    end
  end

  defp analyze_user_agent_patterns(user_agent_lower) do
    signals = []
    score = 0.0

    # Check for automation tools first (highest priority)
    automation_patterns = BotDetectorConfig.automation_patterns()

    automation_matches =
      Enum.count(
        automation_patterns,
        &Regex.match?(&1, user_agent_lower)
      )

    {signals, score} =
      if automation_matches > 0 do
        {signals ++
           [
             %{
               type: "automation_tool_detected",
               value: "Found #{automation_matches} automation tool patterns",
               weight: 1.0
             }
           ], score + 1.0}
      else
        {signals, score}
      end

    # Strong bot indicators (high confidence) - only if no automation tools found
    {signals, score} =
      if automation_matches == 0 do
        strong_bot_patterns = BotDetectorConfig.strong_bot_patterns()

        strong_matches =
          Enum.count(
            strong_bot_patterns,
            &Regex.match?(&1, user_agent_lower)
          )

        if strong_matches > 0 do
          {signals ++
             [
               %{
                 type: "strong_bot_pattern",
                 value: "Found #{strong_matches} strong bot patterns",
                 weight: 1.0
               }
             ], score + 1.0}
        else
          {signals, score}
        end
      else
        {signals, score}
      end

    # Medium bot indicators - only if no automation tools found
    {signals, score} =
      if automation_matches == 0 do
        medium_bot_patterns = BotDetectorConfig.medium_bot_patterns()

        medium_matches =
          Enum.count(
            medium_bot_patterns,
            &Regex.match?(&1, user_agent_lower)
          )

        if medium_matches > 0 do
          {signals ++
             [
               %{
                 type: "medium_bot_pattern",
                 value: "Found #{medium_matches} medium bot patterns",
                 weight: 0.5
               }
             ], score + 0.5}
        else
          {signals, score}
        end
      else
        {signals, score}
      end

    # Suspicious patterns - only if no automation tools found
    {signals, score} =
      if automation_matches == 0 do
        suspicious_patterns = BotDetectorConfig.suspicious_patterns()

        suspicious_matches =
          Enum.count(
            suspicious_patterns,
            &Regex.match?(&1, user_agent_lower)
          )

        if suspicious_matches > 0 do
          {signals ++
             [
               %{
                 type: "suspicious_pattern",
                 value: "Found #{suspicious_matches} suspicious patterns",
                 weight: 0.3
               }
             ], score + 0.3}
        else
          {signals, score}
        end
      else
        {signals, score}
      end

    # Missing or very short user agent
    {signals, score} =
      if String.length(user_agent_lower) < 10 do
        {signals ++
           [
             %{
               type: "short_user_agent",
               value:
                 "User agent too short (#{String.length(user_agent_lower)} chars)",
               weight: 0.6
             }
           ], score + 0.6}
      else
        {signals, score}
      end

    # Browser patterns (negative signals) - only apply if no automation tools detected
    {signals, score} =
      if automation_matches == 0 do
        browser_patterns = BotDetectorConfig.browser_patterns()

        browser_matches =
          Enum.count(
            browser_patterns,
            &Regex.match?(&1, user_agent_lower)
          )

        if browser_matches > 0 do
          {signals ++
             [
               %{
                 type: "browser_detected",
                 value: "Found #{browser_matches} browser patterns",
                 weight: -0.2
               }
             ], max(0.0, score - 0.2)}
        else
          {signals, score}
        end
      else
        {signals, score}
      end

    {signals, min(score, 1.0)}
  end

  @spec analyze_ip_address(String.t()) :: {list(), float()}
  defp analyze_ip_address(ip) when is_binary(ip) and ip != "" do
    signals = []
    score = 0.0

    # Check whitelisted IPs first
    if ip in BotDetectorConfig.whitelisted_ips() do
      {[%{type: "whitelisted_ip", value: "IP is whitelisted", weight: -1.0}],
       0.0}
    else
      # Check blacklisted IPs
      if ip in BotDetectorConfig.blacklisted_ips() do
        {[%{type: "blacklisted_ip", value: "IP is blacklisted", weight: 1.0}],
         1.0}
      else
        # Known bot IP ranges (you can expand this list)
        bot_ip_patterns = BotDetectorConfig.suspicious_ip_ranges()

        bot_matches = Enum.count(bot_ip_patterns, &Regex.match?(&1, ip))

        signals =
          if bot_matches > 0 do
            signals ++
              [
                %{
                  type: "suspicious_ip",
                  value: "IP matches bot patterns",
                  weight: 0.4
                }
              ]
          else
            signals
          end

        score =
          if bot_matches > 0 do
            score + 0.4
          else
            score
          end

        {signals, min(score, 1.0)}
      end
    end
  end

  defp analyze_ip_address(_),
    do: {[%{type: "missing_ip", value: "No IP provided", weight: 0.3}], 0.3}

  @spec analyze_behavioral_patterns(String.t(), String.t()) :: {list(), float()}
  defp analyze_behavioral_patterns(user_agent, ip) do
    signals = []
    score = 0.0

    # Check for suspicious header patterns
    {header_signals, header_score} = analyze_header_patterns(user_agent)
    signals = signals ++ header_signals
    # 40% weight for headers
    score = score + header_score * 0.4

    # Check for suspicious IP patterns
    {ip_behavior_signals, ip_behavior_score} = analyze_ip_behavior_patterns(ip)
    signals = signals ++ ip_behavior_signals
    # 30% weight for IP behavior
    score = score + ip_behavior_score * 0.3

    # Check for automation tool patterns
    {automation_signals, automation_score} =
      analyze_automation_patterns(user_agent)

    signals = signals ++ automation_signals
    # 30% weight for automation
    score = score + automation_score * 0.3

    {signals, min(score, 1.0)}
  end

  @spec analyze_header_patterns(String.t()) :: {list(), float()}
  defp analyze_header_patterns(user_agent)
       when is_binary(user_agent) and user_agent != "" do
    user_agent_lower = String.downcase(user_agent)
    signals = []
    score = 0.0

    # Check for missing or suspicious header patterns
    suspicious_header_patterns = BotDetectorConfig.suspicious_header_patterns()

    suspicious_matches =
      Enum.count(
        suspicious_header_patterns,
        &Regex.match?(&1, user_agent_lower)
      )

    signals =
      if suspicious_matches > 0 do
        signals ++
          [
            %{
              type: "suspicious_header_pattern",
              value: "Found #{suspicious_matches} suspicious header patterns",
              weight: 0.4
            }
          ]
      else
        signals
      end

    score =
      if suspicious_matches > 0 do
        score + 0.4
      else
        score
      end

    # Check for missing browser engine information
    browser_engines = BotDetectorConfig.browser_engine_patterns()

    engine_matches =
      Enum.count(browser_engines, &Regex.match?(&1, user_agent_lower))

    signals =
      if engine_matches == 0 and String.length(user_agent) > 20 do
        signals ++
          [
            %{
              type: "missing_browser_engine",
              value: "No browser engine detected",
              weight: 0.3
            }
          ]
      else
        signals
      end

    score =
      if engine_matches == 0 and String.length(user_agent) > 20 do
        score + 0.3
      else
        score
      end

    {signals, min(score, 1.0)}
  end

  defp analyze_header_patterns(_),
    do:
      {[
         %{
           type: "missing_user_agent",
           value: "No user agent for header analysis",
           weight: 0.5
         }
       ], 0.5}

  @spec analyze_ip_behavior_patterns(String.t()) :: {list(), float()}
  defp analyze_ip_behavior_patterns(ip) when is_binary(ip) and ip != "" do
    signals = []
    score = 0.0

    # Check for datacenter IP patterns (common for bots)
    datacenter_patterns = BotDetectorConfig.datacenter_ip_patterns()
    datacenter_matches = Enum.count(datacenter_patterns, &Regex.match?(&1, ip))

    signals =
      if datacenter_matches > 0 do
        signals ++
          [
            %{
              type: "datacenter_ip",
              value: "IP matches datacenter patterns",
              weight: 0.3
            }
          ]
      else
        signals
      end

    score =
      if datacenter_matches > 0 do
        score + 0.3
      else
        score
      end

    # Check for suspicious IP ranges
    suspicious_ip_ranges = BotDetectorConfig.suspicious_ip_ranges()
    suspicious_matches = Enum.count(suspicious_ip_ranges, &Regex.match?(&1, ip))

    signals =
      if suspicious_matches > 0 do
        signals ++
          [
            %{
              type: "suspicious_ip_range",
              value: "IP in suspicious range",
              weight: 0.4
            }
          ]
      else
        signals
      end

    score =
      if suspicious_matches > 0 do
        score + 0.4
      else
        score
      end

    {signals, min(score, 1.0)}
  end

  defp analyze_ip_behavior_patterns(_),
    do:
      {[
         %{
           type: "missing_ip",
           value: "No IP for behavior analysis",
           weight: 0.3
         }
       ], 0.3}

  @spec analyze_automation_patterns(String.t()) :: {list(), float()}
  defp analyze_automation_patterns(user_agent)
       when is_binary(user_agent) and user_agent != "" do
    user_agent_lower = String.downcase(user_agent)
    signals = []
    score = 0.0

    # Automation and testing tools
    automation_patterns = BotDetectorConfig.automation_patterns()

    automation_matches =
      Enum.count(automation_patterns, &Regex.match?(&1, user_agent_lower))

    signals =
      if automation_matches > 0 do
        signals ++
          [
            %{
              type: "automation_tool",
              value: "Found #{automation_matches} automation patterns",
              weight: 1.0
            }
          ]
      else
        signals
      end

    score =
      if automation_matches > 0 do
        score + 1.0
      else
        score
      end

    # Check for suspicious automation indicators
    suspicious_automation_flags =
      BotDetectorConfig.suspicious_automation_flags()

    suspicious_matches =
      Enum.count(
        suspicious_automation_flags,
        &Regex.match?(&1, user_agent_lower)
      )

    signals =
      if suspicious_matches > 0 do
        signals ++
          [
            %{
              type: "suspicious_automation_flags",
              value: "Found #{suspicious_matches} suspicious automation flags",
              weight: 0.6
            }
          ]
      else
        signals
      end

    score =
      if suspicious_matches > 0 do
        score + 0.6
      else
        score
      end

    {signals, min(score, 1.0)}
  end

  defp analyze_automation_patterns(_),
    do:
      {[
         %{
           type: "missing_user_agent",
           value: "No user agent for automation analysis",
           weight: 0.3
         }
       ], 0.3}

  # Caching and rate limiting functions

  @spec generate_cache_key(String.t(), String.t(), String.t()) :: String.t()
  defp generate_cache_key(user_agent, ip, origin) do
    :crypto.hash(:sha256, "#{user_agent}|#{ip}|#{origin}")
    |> Base.encode16(case: :lower)
  end

  @spec get_cached_result(String.t()) :: {:ok, map()} | :not_found
  defp get_cached_result(cache_key) do
    if BotDetectorConfig.enable_caching() do
      case :ets.lookup(:bot_detector_cache, cache_key) do
        [{^cache_key, result, timestamp}] ->
          if DateTime.diff(DateTime.utc_now(), timestamp, :second) <
               BotDetectorConfig.cache_ttl() do
            {:ok, result}
          else
            :ets.delete(:bot_detector_cache, cache_key)
            :not_found
          end

        [] ->
          :not_found
      end
    else
      :not_found
    end
  end

  @spec cache_result(String.t(), map()) :: :ok
  defp cache_result(cache_key, result) do
    if BotDetectorConfig.enable_caching() do
      :ets.insert(:bot_detector_cache, {cache_key, result, DateTime.utc_now()})
    end

    :ok
  end

  @spec check_rate_limit(String.t()) :: :ok | {:error, :rate_limited}
  defp check_rate_limit(ip) do
    if BotDetectorConfig.enable_rate_limiting() do
      key = {:rate_limit, ip}
      now = DateTime.utc_now()

      case :ets.lookup(:bot_detector_rate_limit, key) do
        [{^key, count, timestamp}] ->
          if DateTime.diff(now, timestamp, :second) < 60 do
            if count >= BotDetectorConfig.max_requests_per_minute() do
              {:error, :rate_limited}
            else
              :ets.insert(:bot_detector_rate_limit, {key, count + 1, timestamp})
              :ok
            end
          else
            :ets.insert(:bot_detector_rate_limit, {key, 1, now})
            :ok
          end

        [] ->
          :ets.insert(:bot_detector_rate_limit, {key, 1, now})
          :ok
      end
    else
      :ok
    end
  end

  @spec generate_request_id() :: String.t()
  defp generate_request_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Initializes the bot detector ETS tables.
  Should be called during application startup.
  """
  def init do
    # Create cache table with ordered_set for better performance
    :ets.new(:bot_detector_cache, [:set, :public, :named_table])

    # Create rate limit table
    :ets.new(:bot_detector_rate_limit, [:set, :public, :named_table])

    # Start cleanup process
    start_cleanup_process()

    :ok
  end

  @doc """
  Cleans up expired cache entries and rate limit records.
  """
  def cleanup do
    now = DateTime.utc_now()

    # Clean cache
    :ets.select_delete(:bot_detector_cache, [
      {{:_, :_, :"$1"},
       [
         {:<, {:-, {:const, now}, :"$1"},
          {:const, BotDetectorConfig.cache_ttl() * 1000}}
       ], [true]}
    ])

    # Clean rate limits (older than 2 minutes)
    :ets.select_delete(:bot_detector_rate_limit, [
      {{:_, :_, :"$1"},
       [{:<, {:-, {:const, now}, :"$1"}, {:const, 120 * 1000}}], [true]}
    ])
  end

  defp start_cleanup_process do
    spawn(fn -> cleanup_loop() end)
  end

  defp cleanup_loop do
    Process.sleep(BotDetectorConfig.cleanup_interval())
    cleanup()
    cleanup_loop()
  end

  # Helper functions for conditional operations
  defp get_cached_result_if_enabled(cache_key), do: get_cached_result(cache_key)

  defp cache_result_if_enabled(cache_key, result),
    do: cache_result(cache_key, result)

  defp check_rate_limit_if_enabled(ip), do: check_rate_limit(ip)
end
