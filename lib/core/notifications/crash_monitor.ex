defmodule Core.Notifications.CrashMonitor do
  @moduledoc """
  Logger backend that captures crashes and sends them to Slack.
  Includes rate limiting and error prevention to avoid notification loops.
  """

  @behaviour :gen_event
  alias Core.Notifications.Slack
  require Logger

  # Rate limiting: max 5 alerts per 5 minutes
  @max_alerts_per_window 5
  @rate_limit_window_seconds 300

  def init(_opts) do
    {:ok,
     %{
       alerts_sent: [],
       total_crashes: 0
     }}
  end

  def handle_call({:configure, _opts}, state) do
    {:ok, :ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, _timestamp, metadata}}, state)
      when level in [:error] do
    if crash_report?(msg) and should_send_alert?(state) do
      # Send alert in background to avoid blocking logging
      Task.start(fn ->
        send_crash_notification(msg, metadata)
      end)

      # Update state with new alert timestamp
      new_state = update_alert_state(state)
      {:ok, new_state}
    else
      {:ok, %{state | total_crashes: state.total_crashes + 1}}
    end
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  # Detect if this is actually a crash report
  defp crash_report?(msg) do
    msg_str = to_string(msg)

    # Look for common crash indicators
    crash_indicators = [
      "GenServer",
      "Task",
      "Process",
      "crashed",
      "terminated",
      "** (exit)",
      "** (throw)",
      "** (error)",
      "** (ArithmeticError)",
      "** (RuntimeError)",
      "** (MatchError)",
      "** (FunctionClauseError)",
      "EXIT"
    ]

    # Must contain crash indicator AND not be our own notifications
    Enum.any?(crash_indicators, &String.contains?(msg_str, &1)) and
      not slack_notification_error?(msg_str)
  end

  # Prevent infinite loops from our own Slack notification failures
  defp slack_notification_error?(msg_str) do
    String.contains?(msg_str, [
      "Finch",
      "Slack",
      "webhook",
      "Core.Notifications"
    ])
  end

  # Rate limiting logic
  defp should_send_alert?(state) do
    now = System.system_time(:second)

    # Remove old alerts outside the window
    recent_alerts =
      Enum.filter(state.alerts_sent, fn timestamp ->
        now - timestamp < @rate_limit_window_seconds
      end)

    # Check if we're under the limit
    length(recent_alerts) < @max_alerts_per_window
  end

  defp update_alert_state(state) do
    now = System.system_time(:second)

    # Add current timestamp and clean old ones
    new_alerts =
      [now | state.alerts_sent]
      |> Enum.filter(fn timestamp ->
        now - timestamp < @rate_limit_window_seconds
      end)

    %{state | alerts_sent: new_alerts, total_crashes: state.total_crashes + 1}
  end

  defp send_crash_notification(msg, metadata) do
    try do
      # Extract useful information
      error_type = extract_error_type(msg)
      error_message = format_error_message(msg)
      location = extract_location(metadata, msg)
      stacktrace = extract_stacktrace(msg)

      # Send to Slack
      case Slack.notify_crash(error_type, error_message, location, stacktrace) do
        :ok ->
          :ok

        {:error, reason} ->
          # Log but don't crash - we don't want notification failures to cause more crashes
          Logger.warning(
            "Failed to send crash notification to Slack: #{inspect(reason)}"
          )
      end
    rescue
      error ->
        # Absolutely prevent notification errors from causing more notifications
        Logger.warning("Error in crash notification system: #{inspect(error)}")
    end
  end

  defp extract_error_type(msg) do
    msg_str = to_string(msg)

    cond do
      String.contains?(msg_str, "GenServer") ->
        "GenServer Crash"

      String.contains?(msg_str, "Task") ->
        "Task Crash"

      String.contains?(msg_str, "** (") ->
        # Extract exception type from ** (ExceptionType) format
        case Regex.run(~r/\*\* \(([^)]+)\)/, msg_str) do
          [_, exception_type] -> exception_type
          _ -> "Exception"
        end

      true ->
        "Process Exit"
    end
  end

  defp format_error_message(msg) do
    msg_str = to_string(msg)

    # Try to extract the actual error message, not the full crash report
    if String.contains?(msg_str, "** (") do
      # Extract message after exception type
      case Regex.run(~r/\*\* \([^)]+\) (.+)/, msg_str) do
        [_, error_msg] ->
          error_msg
          |> String.split("\n")
          |> List.first()
          |> String.slice(0, 200)

        _ ->
          String.slice(msg_str, 0, 200)
      end
    else
      # Just take first line and truncate
      msg_str
      |> String.split("\n")
      |> List.first()
      |> String.slice(0, 200)
    end
  end

  defp extract_location(metadata, msg) do
    cond do
      # Try to get from metadata first (most reliable)
      metadata[:mfa] ->
        {mod, fun, arity} = metadata[:mfa]
        "#{mod}.#{fun}/#{arity}"

      metadata[:module] ->
        "#{metadata[:module]}"

      # Try to extract from crash report
      true ->
        msg_str = to_string(msg)

        case Regex.run(~r/\(([A-Z][A-Za-z0-9.]+)\)/, msg_str) do
          [_, module] -> module
          _ -> nil
        end
    end
  end

  defp extract_stacktrace(msg) do
    msg_str = to_string(msg)

    # Look for stacktrace in the message
    if String.contains?(msg_str, "stacktrace") or
         String.contains?(msg_str, "    (") do
      # Try to extract just the stacktrace part
      lines = String.split(msg_str, "\n")

      stacktrace_lines =
        lines
        |> Enum.drop_while(fn line ->
          not String.contains?(line, ["stacktrace", "    ("])
        end)
        # Limit to first 10 lines of stacktrace
        |> Enum.take(10)

      if length(stacktrace_lines) > 0 do
        Enum.join(stacktrace_lines, "\n")
      else
        nil
      end
    else
      nil
    end
  end
end
