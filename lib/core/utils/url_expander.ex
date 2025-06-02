defmodule Core.Utils.UrlExpander do
  @moduledoc """
  Provides functionality for expanding shortened URLs to their full domains.

  This module handles:
  - Detection of shortened URLs (e.g., bit.ly, hubs.ly)
  - Expansion of shortened URLs to their full domains
  - Validation of URL formats
  - Error handling for invalid or unexpandable URLs
  - Integration with primary domain finder

  The module ensures that shortened URLs are properly expanded while maintaining
  proper error handling and validation throughout the process.
  """

  alias Core.Utils.Errors

  @doc """
  Expands shortened URLs to their full domain.
  Returns {expanded_domain, was_expanded}.
  """
  @spec expand_short_url(String.t()) ::
          {:ok, String.t()} | Core.Utils.Errors.url_error()
  def expand_short_url(domain) when is_binary(domain) do
    url_shorteners = [
      "bit.ly/",
      "hubs.ly/"
    ]

    shortener_found =
      Enum.any?(url_shorteners, fn shortener ->
        String.contains?(domain, shortener)
      end)

    if shortener_found do
      case Core.Utils.PrimaryDomainFinder.get_primary_domain(domain) do
        {:ok, expanded_domain} when expanded_domain != "" ->
          {:ok, expanded_domain}

        {:ok, ""} ->
          Errors.error(:unable_to_expand_url)

        {:error, reason} ->
          Errors.error(reason)
      end
    else
      {:ok, domain}
    end
  end

  def expand_short_url(nil), do: Errors.error(:url_not_provided)
  def expand_short_url(""), do: Errors.error(:url_not_provided)
  def expand_short_url(_), do: Errors.error(:invalid_url)
end
