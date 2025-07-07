defmodule Core.Utils.FormatLocation do
  @moduledoc """
  Module for formatting contact locations with country and city.
  """

  @doc """
  Formats location from country_a2 and city fields.

  ## Examples

      iex> FormatLocation.format("US", "Seattle")
      "United States • Seattle"

      iex> FormatLocation.format("GB", "London")
      "United Kingdom • London"
  """
  def format(country_a2, city) do
    cond do
      is_nil(country_a2) and is_nil(city) ->
        nil

      is_nil(country_a2) ->
        city

      is_nil(city) ->
        get_country_name(country_a2)

      true ->
        "#{get_country_name(country_a2)} • #{city}"
    end
  end

  defp get_country_name(nil), do: nil

  defp get_country_name(country_a2) do
    case CountryData.search_countries_by_alpha2(country_a2) do
      [%{"name" => name} | _] -> name
      [%{name: name} | _] -> name
      _ -> country_a2
    end
  end
end
