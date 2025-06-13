defmodule Core.Utils.Retry do
  @moduledoc """
  Utility for adding retry to function calls
  """

  require Logger

  @retry_delay_ms 1000

  def with_delay(function, max_retries, delay \\ @retry_delay_ms, attempt \\ 0) do
    Logger.info("Retries: #{attempt}")

    case function.() do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} when attempt < max_retries ->
        OpenTelemetry.Tracer.set_attributes([
          {"retry.attempt", attempt + 1},
          {"retry.remaining", max_retries - attempt - 1}
        ])

        Process.sleep(delay)
        with_delay(function, max_retries, delay, attempt + 1)

      {:error, reason} ->
        Logger.warning("Retry failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
