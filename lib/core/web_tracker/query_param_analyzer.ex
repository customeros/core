defmodule Core.WebTracker.QueryParamAnalyzer do
  @utm_params [
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_term",
    "utm_content"
  ]

  def has_utm_params?(query_string) when is_binary(query_string) do
    query_string
    |> parse_query_params()
    |> has_any_utm_params?()
  end

  def has_utm_params?(_), do: false

  defp parse_query_params(query_string) do
    query_string
    |> String.trim_leading("?")
    |> URI.decode_query()
  end

  defp has_any_utm_params?(param_map) when is_map(param_map) do
    Enum.any?(@utm_params, fn param ->
      case Map.get(param_map, param) do
        nil -> false
        "" -> false
        _value -> true
      end
    end)
  end

  defp has_any_utm_params?(_), do: false
end
