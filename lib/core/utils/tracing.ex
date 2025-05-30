defmodule Core.Utils.Tracing do
  @moduledoc """
  Utility functions for tracing.
  """

  import OpenTelemetry.Tracer,
    only: [set_status: 1, set_attributes: 1, current_span_ctx: 0]

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
        set_status(:error)

        set_attributes([
          {"error.reason", inspect(reason)}
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
end
