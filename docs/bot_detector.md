# Bot Detector Documentation

## Overview

The Bot Detector module provides sophisticated bot detection capabilities for the web tracker system. It analyzes user agents, IP addresses, and behavioral patterns to identify non-human traffic and prevent bot activity from polluting analytics data.

## Features

### Multi-Signal Detection
- **User Agent Analysis**: Detects bot patterns, automation tools, and suspicious user agent strings
- **IP Address Analysis**: Identifies datacenter IPs, private networks, and suspicious IP ranges
- **Behavioral Analysis**: Analyzes header patterns, automation flags, and suspicious behaviors

### Configurable Detection
- Configurable confidence thresholds
- Adjustable signal weights
- Whitelist/blacklist support for user agents and IPs
- Customizable pattern matching

### Performance Features
- ETS-based caching for improved performance
- Rate limiting to prevent abuse
- Automatic cleanup of expired cache entries
- Configurable cache TTL and cleanup intervals

## Usage

### Basic Usage

```elixir
# Detect if a request is from a bot
{:ok, result} = Core.WebTracker.BotDetector.detect_bot(
  user_agent, 
  ip_address, 
  origin, 
  referrer
)

# Result structure
%{
  bot: true,                    # Boolean indicating if it's a bot
  confidence: 0.85,            # Confidence score (0.0 to 1.0)
  signals: [                   # List of detection signals
    %{
      type: "strong_bot_pattern",
      value: "Found 1 strong bot patterns",
      weight: 0.8
    }
  ],
  timestamp: "2024-01-01T00:00:00Z",
  source: "custom_bot_detection",
  request_id: "abc123..."
}
```

### Integration with Event Creation

The bot detector is automatically integrated into the web tracker event creation process. Events from detected bots are rejected with appropriate error messages.

```elixir
# This happens automatically in Event.changeset/2
def validate_bot(changeset) do
  user_agent = get_field(changeset, :user_agent)
  ip = get_field(changeset, :ip)
  origin = get_field(changeset, :origin)
  referrer = get_field(changeset, :referrer)

  case Core.WebTracker.BotDetector.detect_bot(user_agent, ip, origin, referrer) do
    {:ok, %{bot: true, confidence: confidence}} ->
      add_error(changeset, :user_agent, "Bot detected with confidence #{Float.round(confidence, 2)}")
    
    {:ok, %{bot: false}} ->
      changeset
    
    {:error, _reason} ->
      # Fall back to simple detection
      if bot_user_agent?(user_agent) do
        add_error(changeset, :user_agent, "Bot requests are not allowed")
      else
        changeset
      end
  end
end
```

### Standalone Bot Detection Endpoint

A dedicated endpoint is available for bot detection:

```bash
GET /v1/events/bot-detect
Headers:
  user-agent: Mozilla/5.0...
  ip: 192.168.1.1
  origin: example.com
  referrer: https://google.com
```

## Configuration

### Environment Variables

The bot detector can be configured using environment variables:

```elixir
# config/config.exs
config :core, :bot_detector_cache_ttl, 300                    # Cache TTL in seconds
config :core, :bot_detector_max_requests_per_minute, 100      # Rate limit
config :core, :bot_detector_confidence_threshold, 0.7         # Bot detection threshold
config :core, :bot_detector_enable_caching, true              # Enable/disable caching
config :core, :bot_detector_enable_rate_limiting, true        # Enable/disable rate limiting
config :core, :bot_detector_enable_detailed_logging, false    # Enable detailed logging
config :core, :bot_detector_cleanup_interval, 60_000          # Cleanup interval in ms

# Signal weights
config :core, :bot_detector_signal_weights, %{
  user_agent: 0.6,    # 60% weight for user agent analysis
  ip_address: 0.3,    # 30% weight for IP analysis
  behavioral: 0.1     # 10% weight for behavioral analysis
}

# Whitelist/blacklist configuration
config :core, :bot_detector_whitelisted_user_agents, [
  "trusted-bot/1.0",
  "my-custom-crawler"
]

config :core, :bot_detector_blacklisted_user_agents, [
  "malicious-bot",
  "scraper-tool"
]

config :core, :bot_detector_whitelisted_ips, [
  "192.168.1.100",
  "10.0.0.50"
]

config :core, :bot_detector_blacklisted_ips, [
  "192.168.1.200",
  "10.0.0.100"
]
```

### Custom Pattern Configuration

You can customize detection patterns:

```elixir
# Custom automation tools to detect
config :core, :bot_detector_automation_tools, [
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
]

# Custom suspicious automation flags
config :core, :bot_detector_suspicious_automation_flags, [
  "headless",
  "no-sandbox",
  "disable-dev-shm-usage",
  "disable-gpu",
  "disable-web-security",
  # ... more flags
]

# Custom datacenter IP patterns
config :core, :bot_detector_datacenter_ip_patterns, [
  ~r/^8\.8\.8\.8$/i,         # Google DNS
  ~r/^1\.1\.1\.1$/i,         # Cloudflare DNS
  ~r/^208\.67\.222\.222$/i,  # OpenDNS
  ~r/^9\.9\.9\.9$/i          # Quad9 DNS
]

# Custom suspicious IP ranges
config :core, :bot_detector_suspicious_ip_ranges, [
  ~r/^192\.168\./i,          # Private network
  ~r/^10\./i,                # Private network
  ~r/^172\.(1[6-9]|2[0-9]|3[0-1])\./i,  # Private network
  ~r/^127\.0\.0\.1$/i,       # Localhost
  ~r/^0\.0\.0\.0$/i,         # Invalid IP
  ~r/^::1$/i                 # IPv6 localhost
]
```

## Detection Logic

### User Agent Analysis (60% weight)

1. **Whitelist/Blacklist Check**: Immediate pass/fail based on configured lists
2. **Strong Bot Patterns**: High-confidence bot indicators (Googlebot, Bingbot, etc.)
3. **Medium Bot Patterns**: Common bot patterns (bot, crawler, spider, etc.)
4. **Suspicious Patterns**: Unusual user agent formats
5. **Browser Detection**: Negative signals for legitimate browsers

### IP Address Analysis (30% weight)

1. **Whitelist/Blacklist Check**: Immediate pass/fail based on configured lists
2. **Datacenter IPs**: Known datacenter and DNS server IPs
3. **Suspicious Ranges**: Private networks, localhost, invalid IPs

### Behavioral Analysis (10% weight)

1. **Header Patterns**: Suspicious user agent header formats
2. **IP Behavior**: Datacenter and suspicious IP patterns
3. **Automation Tools**: Detection of automation and testing tools
4. **Suspicious Flags**: Browser automation flags and settings

### Confidence Calculation

The final confidence score is calculated as:
```
confidence = (ua_score * 0.6) + (ip_score * 0.3) + (behavior_score * 0.1)
```

A request is classified as a bot if `confidence > threshold` (default: 0.7).

## Performance Considerations

### Caching
- Results are cached in ETS tables for 5 minutes (configurable)
- Cache keys are SHA256 hashes of user agent + IP + origin
- Automatic cleanup of expired entries

### Rate Limiting
- 100 requests per minute per IP (configurable)
- Rate limiting can be disabled for testing

### Memory Usage
- ETS tables are automatically cleaned up
- Cleanup runs every minute (configurable)
- Rate limit records expire after 2 minutes

## Testing

Run the bot detector tests:

```bash
mix test test/core/web_tracker/bot_detector_test.exs
```

The test suite covers:
- Known bot user agents
- Automation tools
- Legitimate browsers
- Suspicious IPs
- Edge cases
- Caching behavior
- Rate limiting

## Monitoring

### OpenTelemetry Integration
The bot detector includes comprehensive OpenTelemetry tracing:
- Span creation for each detection request
- Attribute tracking for input parameters
- Error tracking for failed detections

### Logging
- Debug logging for cache hits (when enabled)
- Warning logs for rate limit violations
- Error logs for detection failures

## Troubleshooting

### Common Issues

1. **False Positives**: Adjust confidence threshold or add patterns to whitelist
2. **False Negatives**: Add patterns to blacklist or adjust signal weights
3. **Performance Issues**: Disable caching or rate limiting for testing
4. **Memory Usage**: Check cleanup interval and cache TTL settings

### Debug Mode

Enable detailed logging for debugging:

```elixir
config :core, :bot_detector_enable_detailed_logging, true
```

This will log cache hits and detailed detection signals.

## Security Considerations

1. **Input Validation**: All inputs are validated and sanitized
2. **Rate Limiting**: Prevents abuse of the detection service
3. **Caching**: Reduces computational overhead
4. **Configurable**: Allows fine-tuning for specific use cases
5. **Fallback**: Simple detection as backup for sophisticated detection failures

## Future Enhancements

Potential improvements for future versions:
- Machine learning-based detection
- Geographic pattern analysis
- Session behavior analysis
- Real-time threat intelligence integration
- Distributed caching with Redis
- Advanced behavioral fingerprinting
