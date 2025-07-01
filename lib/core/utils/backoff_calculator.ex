defmodule Core.Utils.BackoffCalculator do
  @doc """
  Calculates the next check time using exponential backoff.
  Base delay starts at 1 min and doubles each attempt.  Max delay capped at 24 hours.
  """
  def next_check_time(attempt_count, add_jitter \\ true) do
    delay_seconds = calculate_delay_seconds(attempt_count)

    final_delay =
      if add_jitter do
        add_jitter(delay_seconds)
      else
        delay_seconds
      end

    DateTime.add(DateTime.utc_now(), final_delay, :second)
  end

  defp add_jitter(delay_seconds) do
    jitter_range = trunc(delay_seconds * 0.25)
    jitter = :rand.uniform(jitter_range * 2) - jitter_range
    delay_seconds + jitter
  end

  defp calculate_delay_seconds(attempt_count) do
    base_delay = 60
    exponential_delay = base_delay * :math.pow(2, attempt_count)
    max_delay = 24 * 60 * 60
    min(trunc(exponential_delay), max_delay)
  end
end
