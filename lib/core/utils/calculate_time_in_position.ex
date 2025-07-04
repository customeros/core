defmodule Core.Utils.CalculateTimeInPosition do
  @moduledoc """
  Module for calculating human-readable time durations for contact positions.
  """

  @doc """
  Calculates the time in position and returns a human-readable string.

  ## Examples

      iex> CalculateTimeInPosition.calculate(start_date, end_date)
      "3 years and 4 months"

      iex> CalculateTimeInPosition.calculate(start_date, nil)  # current position
      "2 years and 6 months"
  """
  def calculate(started_at, ended_at) do
    cond do
      # If job ended, calculate duration
      not is_nil(ended_at) and not is_nil(started_at) ->
        calculate_human_duration(started_at, ended_at)

      # If still current position (no end date)
      is_nil(ended_at) and not is_nil(started_at) ->
        calculate_human_duration(started_at, DateTime.utc_now())

      # No start date available
      true ->
        nil
    end
  end

  defp calculate_human_duration(start_date, end_date) do
    import Timex.Duration

    duration = Timex.diff(end_date, start_date, :duration)

    years = Duration.to_years(duration)
    months = Duration.to_months(duration) |> rem(12)

    cond do
      years > 0 and months > 0 ->
        "#{years} #{if years == 1, do: "year", else: "years"} and #{months} #{if months == 1, do: "month", else: "months"}"

      years > 0 ->
        "#{years} #{if years == 1, do: "year", else: "years"}"

      months > 0 ->
        "#{months} #{if months == 1, do: "month", else: "months"}"

      true ->
        days = Duration.to_days(duration)
        "#{days} #{if days == 1, do: "day", else: "days"}"
    end
  end
end
