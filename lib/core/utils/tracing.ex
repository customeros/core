defmodule Core.Utils.Tracing do
  @moduledoc """
  Utility functions for tracing.
  """

  require OpenTelemetry.Tracer

  @doc """
  Sets the status of the current span to error with the given reason.
  Does nothing if no active span context is present.
  """
  def error(reason) do
    case OpenTelemetry.Tracer.current_span_ctx() do
      :undefined ->
        :ok

      _ctx ->
        reason_str = to_reason_string(reason)
        OpenTelemetry.Tracer.set_status(:error, reason_str)

        OpenTelemetry.Tracer.set_attributes([
          {"error.reason", reason_str}
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

  def to_reason_string(reason) do
    try do
      to_string(reason)
    rescue
      Protocol.UndefinedError ->
        inspect(reason)
    end
  end
end
