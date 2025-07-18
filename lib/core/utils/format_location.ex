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
    country = get_country_name(country_a2)
    city = if is_nil(city) or city == "", do: nil, else: city
    country = if is_nil(country) or country == "", do: nil, else: country

    cond do
      is_nil(country) and is_nil(city) ->
        nil

      is_nil(country) ->
        city

      is_nil(city) ->
        country

      true ->
        "#{country} • #{city}"
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
