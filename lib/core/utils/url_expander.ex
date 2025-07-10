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

  require Logger
  alias Core.Utils.DomainIO

  @err_empty_url {:error, "empty url"}
  @err_invalid_url {:error, "invalid_url"}

  # Known URL shorteners that should be treated as invalid domains
  @url_shorteners [
    "adf.ly",
    "bit.do",
    "bit.ly",
    "buff.ly",
    "bc.vc",
    "cutt.ly",
    "chilp.it",
    "clk.im",
    "fb.me",
    "goo.gl",
    "is.gd",
    "ity.im",
    "j.mp",
    "lc.chat",
    "linktr.ee",
    "lnkd.in",
    "mcaf.ee",
    "ow.ly",
    "po.st",
    "q.gs",
    "rb.gy",
    "sh.st",
    "shorte.st",
    "short.ly",
    "short.to",
    "shorturl.at",
    "shorturl.com",
    "snip.ly",
    "soo.gd",
    "soo.nr",
    "t.co",
    "tiny.cc",
    "tiny.ie",
    "tiny.one",
    "tinyurl.com",
    "trib.al",
    "v.gd",
    "x.co",
    "zi.ma",
    "budurl.com"
  ]

  @doc """
  Expands shortened URLs to their full domain by following one redirect.
  Returns {:ok, expanded_domain} or {:error, reason}.
  """
  def expand_short_url(url) when is_binary(url) do
    clean_url = clean_url_for_check(url)

    shortener_found =
      Enum.find(@url_shorteners, fn shortener ->
        String.starts_with?(clean_url, shortener <> "/")
      end)

    if shortener_found do
      Logger.info("Expanding short url: #{url}")

      case follow_single_redirect(url) do
        {:ok, expanded_url} ->
          case extract_domain_from_url(expanded_url) do
            {:ok, domain} -> {:ok, domain}
            {:error, reason} -> {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, url}
    end
  end

  def expand_short_url(nil), do: @err_empty_url
  def expand_short_url(""), do: @err_empty_url
  def expand_short_url(_), do: @err_invalid_url

  defp clean_url_for_check(url) do
    url
    |> String.replace_prefix("http://", "")
    |> String.replace_prefix("https://", "")
    |> String.replace_prefix("www.", "")
    |> String.trim("/")
  end

  defp follow_single_redirect(url) do
    # Add protocol if missing
    full_url =
      if String.starts_with?(url, "http"), do: url, else: "https://#{url}"

    case DomainIO.test_redirect(full_url) do
      {:ok, {:redirect, headers}} ->
        # Extract location header for redirects
        location = find_location_header(headers)

        if location && location != "" do
          {:ok, location}
        else
          {:ok, full_url}
        end

      {:ok, {:no_redirect}} ->
        {:ok, full_url}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_location_header(headers) do
    Enum.find_value(headers, nil, fn
      {"location", value} -> value
      {"Location", value} -> value
      _ -> nil
    end)
  end

  defp extract_domain_from_url(url) do
    case Core.Utils.DomainExtractor.extract_base_domain(url) do
      {:ok, domain} -> {:ok, domain}
      {:error, reason} -> {:error, reason}
    end
  end

  def url_shorteners, do: @url_shorteners
end
