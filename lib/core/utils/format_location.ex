defmodule Core.Utils.FormatLocation do
  @moduledoc """
  Module for formatting contact locations with country, city, and local time.
  """

  @doc """
  Formats location from country_a2 and city fields.

  ## Examples

      iex> FormatLocation.format("US", "Seattle")
      "USA • Seattle • 8:39 local time"

      iex> FormatLocation.format("GB", "London")
      "United Kingdom • London • 14:30 local time"
  """
  def format(country_a2, city) do
    cond do
      is_nil(country_a2) and is_nil(city) ->
        nil

      is_nil(country_a2) ->
        "#{city} • #{get_local_time(nil, city)}"

      is_nil(city) ->
        "#{get_country_name(country_a2)} • #{get_local_time(country_a2, nil)}"

      true ->
        "#{get_country_name(country_a2)} • #{city} • #{get_local_time(country_a2, city)}"
    end
  end

  defp get_country_name(country_a2) do
    case Countriex.get_by(:alpha2, country_a2) do
      %{name: name} -> name
      _ -> country_a2
    end
  end

  defp get_local_time(country_a2, city) do
    # Try to get timezone from country code using Timex
    case get_timezone_from_location(country_a2, city) do
      {:ok, timezone} ->
        case Timex.now(timezone) do
          {:ok, local_time} ->
            Timex.format!(local_time, "{h24}:{m}")
            |> Kernel.<>(" local time")

          {:error, _} ->
            # Fallback to UTC if timezone lookup fails
            Timex.now()
            |> Timex.format!("{h24}:{m}")
            |> Kernel.<>(" local time")
        end

      {:error, _} ->
        # Fallback to UTC if country lookup fails
        Timex.now()
        |> Timex.format!("{h24}:{m}")
        |> Kernel.<>(" local time")
    end
  end

  defp get_timezone_from_location(country_a2, city) do
    # Use Timex to get timezone from country code
    case Timex.timezone_for_country(country_a2) do
      {:ok, timezones} when is_list(timezones) and length(timezones) > 0 ->
        # Take the first timezone (usually the primary one)
        {:ok, List.first(timezones)}

      {:ok, _} ->
        {:error, :no_timezone_found}

      {:error, _} ->
        {:error, :country_not_found}
    end
  end
end
