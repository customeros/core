defmodule Core.Researcher.Webpages.LinkExtractor do
  @moduledoc """
  Extracts and processes links from webpage content.

  This module handles:
  - Link extraction from markdown-formatted content
  - URL validation and normalization
  - Filtering of irrelevant or utility links
  - Duplicate link removal
  - URL cleaning and standardization

  The module implements smart filtering to exclude:
  - Authentication and account management URLs
  - Utility and administrative pages
  - API endpoints and webhooks
  - Search and filtering pages
  - Support and help pages
  - Other non-content URLs

  It ensures that only relevant, content-focused links are extracted
  while maintaining proper URL formatting and validation.
  """

  def extract_links(links_section) do
    links_section
    |> String.split("\n")
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.filter(&String.contains?(&1, "]("))
    |> Stream.map(fn line ->
      case :binary.match(line, "](") do
        {pos, 2} ->
          start = pos + 2
          rest = binary_part(line, start, byte_size(line) - start)

          case :binary.match(rest, ")") do
            {end_pos, 1} ->
              url = binary_part(line, start, end_pos)
              url

            :nomatch ->
              nil
          end

        :nomatch ->
          nil
      end
    end)
    |> Stream.reject(&is_nil/1)
    |> Stream.map(fn url ->
      url
      |> String.trim_trailing("#")
      |> String.trim_trailing("/")
    end)
    |> Stream.filter(fn url ->
      String.starts_with?(url, "http") && url != "" && url != "#"
    end)
    |> Stream.reject(&should_skip_url?/1)
    |> Stream.reject(&file_attachment?/1)
    |> Enum.uniq()
  end

  defp should_skip_url?(url) do
    skip_keywords = [
      "account",
      "admin",
      "api",
      "app",
      "archive",
      "beta",
      "billing",
      "calendar",
      "careers",
      "cart",
      "checkout",
      "console",
      "contact",
      "cookie",
      "dashboard",
      "date",
      "dev",
      "faq",
      "feed",
      "filter",
      "help",
      "jobs",
      "login",
      "logout",
      "mailto",
      "manage",
      "order",
      "page",
      "password",
      "payment",
      "preferences",
      "profile",
      "register",
      "rss",
      "sandbox",
      "search",
      "session",
      "settings",
      "share",
      "signin",
      "signout",
      "signup",
      "sitemap",
      "sort",
      "stage",
      "staging",
      "status",
      "support",
      "tag",
      "tel",
      "terms",
      "test",
      "ticket",
      "token",
      "webhook"
    ]

    lowercase_url = String.downcase(url)

    Enum.any?(skip_keywords, fn keyword ->
      String.contains?(lowercase_url, keyword)
    end)
  end

  defp file_attachment?(url) do
    file_extensions = [
      ".jpg",
      ".jpeg",
      ".png",
      ".gif",
      ".bmp",
      ".svg",
      ".webp",
      ".pdf",
      ".doc",
      ".docx",
      ".xls",
      ".xlsx",
      ".ppt",
      ".pptx",
      ".zip",
      ".rar",
      ".tar",
      ".gz",
      ".7z",
      ".mp3",
      ".wav",
      ".ogg",
      ".mp4",
      ".mov",
      ".avi",
      ".wmv",
      ".mkv",
      ".csv",
      ".txt"
    ]

    lowercase_url = String.downcase(url)

    Enum.any?(file_extensions, fn ext ->
      String.ends_with?(lowercase_url, ext)
    end)
  end
end
