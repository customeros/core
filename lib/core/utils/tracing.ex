defmodule Core.Utils.Tracing do
  @moduledoc """
  Utility functions for tracing.
  """

  import OpenTelemetry.Tracer,
    only: [set_status: 1, set_status: 2, set_attributes: 1, current_span_ctx: 0]

  require OpenTelemetry.Span

  @doc """
  Sets the status of the current span to error with the given reason.
  Does nothing if no active span context is present.
  """
  def error(reason) do
    case current_span_ctx() do
      :undefined ->
        :ok

      _ctx ->
        reason_str = to_reason_string(reason)
        set_status(:error, reason_str)

        set_attributes([
          {"error.reason", reason_str}
        ])
    end
  end

  def ok do
    case current_span_ctx() do
      :undefined ->
        :ok

      _ctx ->
        set_status(:ok)
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
