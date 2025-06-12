defmodule Core.Utils.Retry do
  @retry_delay_ms 1000

  def call_with_delayed_retry(function, max_retries, attempt \\ 0) do
    case function.() do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} when attempt < max_retries ->
        OpenTelemetry.Tracer.set_attributes([
          {"retry.attempt", attempt + 1},
          {"retry.remaining", max_retries - attempt - 1}
        ])

        Process.sleep(@retry_delay_ms)
        call_with_delayed_retry(function, max_retries, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
