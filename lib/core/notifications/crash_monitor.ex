defmodule Core.Notifications.CrashMonitor do
  @moduledoc """
  Logger backend that captures crashes and errors and sends them to Slack.
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
       total_crashes: 0,
       total_errors: 0
     }}
  end

  def handle_call({:configure, _opts}, state) do
    {:ok, :ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, _timestamp, metadata}}, state)
      when level in [:error] do
    if not slack_notification_error?(msg) and should_send_alert?(state) do
      if crash_report?(msg) do
        Task.start(fn ->
          send_crash_notification(msg, metadata)
        end)

        new_state = update_alert_state(state, :crash)
        {:ok, new_state}
      else
        Task.start(fn ->
          send_error_notification(msg, metadata)
        end)

        new_state = update_alert_state(state, :error)
        {:ok, new_state}
      end
    else
      {:ok, %{state | total_errors: state.total_errors + 1}}
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

  defp crash_report?(msg) do
    msg_str = to_string(msg)

    crash_indicators = [
      "GenServer",
      "Task",
      "Process",
      "crashed",
      "terminated",
      "** (exit)",
      "** (throw)",
      "EXIT"
    ]

    Enum.any?(crash_indicators, &String.contains?(msg_str, &1)) and
      not slack_notification_error?(msg_str)
  end

  defp slack_notification_error?(msg) do
    msg_str = to_string(msg)
    String.contains?(msg_str, [
      "Finch",
      "Slack",
      "webhook",
      "Core.Notifications"
    ])
  end

  defp should_send_alert?(state) do
    now = System.system_time(:second)

    recent_alerts =
      Enum.filter(state.alerts_sent, fn timestamp ->
        now - timestamp < @rate_limit_window_seconds
      end)

    length(recent_alerts) < @max_alerts_per_window
  end

  defp update_alert_state(state, type) do
    now = System.system_time(:second)

    new_alerts =
      [now | state.alerts_sent]
      |> Enum.filter(fn timestamp ->
        now - timestamp < @rate_limit_window_seconds
      end)

    case type do
      :crash ->
        %{
          state
          | alerts_sent: new_alerts,
            total_crashes: state.total_crashes + 1
        }

      :error ->
        %{state | alerts_sent: new_alerts, total_errors: state.total_errors + 1}
    end
  end

  defp send_crash_notification(msg, metadata) do
    try do
      error_type = extract_error_type(msg)
      error_message = format_error_message(msg)
      location = extract_location(metadata, msg)
      stacktrace = extract_stacktrace(msg)

      case Slack.notify_crash(error_type, error_message, location, stacktrace) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to send crash notification to Slack: #{inspect(reason)}"
          )
      end
    rescue
      error ->
        Logger.warning("Error in crash notification system: #{inspect(error)}")
    end
  end

  defp send_error_notification(msg, metadata) do
    try do
      error_type = extract_error_type(msg)
      error_message = format_error_message(msg)
      location = extract_location(metadata, msg)
      stacktrace = extract_stacktrace(msg)

      case Slack.notify_error(
             error_type,
             error_message,
             location,
             stacktrace,
             metadata
           ) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to send error notification to Slack: #{inspect(reason)}"
          )
      end
    rescue
      error ->
        Logger.warning("Error in error notification system: #{inspect(error)}")
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

    if String.contains?(msg_str, "** (") do
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
      msg_str
      |> String.split("\n")
      |> List.first()
      |> String.slice(0, 200)
    end
  end

  defp extract_location(metadata, msg) do
    cond do
      metadata[:mfa] ->
        {mod, fun, arity} = metadata[:mfa]
        "#{mod}.#{fun}/#{arity}"

      metadata[:module] ->
        "#{metadata[:module]}"

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

    if String.contains?(msg_str, "stacktrace") or
         String.contains?(msg_str, "    (") do
      lines = String.split(msg_str, "\n")

      stacktrace_lines =
        lines
        |> Enum.drop_while(fn line ->
          not String.contains?(line, ["stacktrace", "    ("])
        end)
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
