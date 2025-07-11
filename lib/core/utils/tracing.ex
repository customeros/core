defmodule Core.Utils.Tracing do
  @moduledoc """
  Utility functions for tracing.
  """

  require Logger
  require OpenTelemetry.Tracer

  @doc """
  Sets the status of the current span to error with the given reason.
  Does nothing if no active span context is present.
  Logs the error message if provided.
  """
  def error(reason, message \\ nil, metadata \\ [])

  def error(reason, message, metadata) do
    reason_str = to_reason_string(reason)

    if message && String.trim(message) != "" do
      message = "#{message}. Reason: #{reason_str}"

      Logger.error(message, Keyword.put_new(metadata, :reason, reason_str))
    end

    case OpenTelemetry.Tracer.current_span_ctx() do
      :undefined ->
        :ok

      _ctx ->
        OpenTelemetry.Tracer.set_status(:error, reason_str)

        OpenTelemetry.Tracer.set_attributes([
          {"error.reason", reason_str}
        ])
    end
  end

  @doc """
  Sets the status of the current span to error with the given reason.
  Does nothing if no active span context is present.
  Logs the warning message if provided.
  """
  @spec warning(term()) :: :ok
  @spec warning(term(), String.t() | nil) :: :ok
  @spec warning(term(), String.t() | nil, keyword()) :: :ok
  def warning(reason, message \\ nil, metadata \\ [])

  def warning(reason, message, metadata) do
    reason_str = to_reason_string(reason)

    if message && String.trim(message) != "" do
      message = "#{message}. Reason: #{reason_str}"

      Logger.warning(message, Keyword.put_new(metadata, :reason, reason_str))
    end

    case OpenTelemetry.Tracer.current_span_ctx() do
      :undefined ->
        :ok

      _ctx ->
        OpenTelemetry.Tracer.set_attributes([
          {"warning.reason", reason_str}
        ])
    end
  end

  def ok do
    case OpenTelemetry.Tracer.current_span_ctx() do
      :undefined ->
        :ok

      _ctx ->
        OpenTelemetry.Tracer.set_status(:ok, "")
    end
  end

  # Private functions

  defp to_reason_string(reason) do
    case reason do
      reason when is_binary(reason) ->
        reason

      reason when is_list(reason) ->
        # Handle lists (like Ecto changeset errors) by inspecting them
        inspect(reason)

      reason ->
        try do
          to_string(reason)
        rescue
          Protocol.UndefinedError ->
            inspect(reason)
        end
    end
  end
end
