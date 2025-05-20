defmodule Core.WebTracker.OriginValidator do
  @moduledoc """
  Validates and checks origins for web tracker events.
  Implements pattern matching to filter out known patterns that should be ignored.
  """

  # List of regex patterns for origins that should be ignored
  @ignore_patterns [
    # HubSpot preview domains (e.g., 123456789.hubspotpreview-na1.com)
    ~r/^\d+\.hubspotpreview-[a-z0-9]+\.com$/,

    # Add more patterns here, for example:
    # ~r/\.staging\.example\.com$/,
    # ~r/\.test\.environment\.com$/,
    # ~r/localhost/
  ]

  @doc """
  Checks if an origin should be ignored based on predefined patterns.
  Returns `true` if the origin should be ignored, `false` otherwise.

  ## Examples

      iex> should_ignore_origin?("123456.hubspotpreview-na1.com")
      true

      iex> should_ignore_origin?("example.com")
      false
  """
  def should_ignore_origin?(origin) when is_binary(origin) do
    Enum.any?(@ignore_patterns, &Regex.match?(&1, origin))
  end

  def should_ignore_origin?(_), do: false
end
