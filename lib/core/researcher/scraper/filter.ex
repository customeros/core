defmodule Researcher.Scraper.Filter do
  @moduledoc """
  Filters out non-scrapeable URLs based on path and file extension.
  """

  @doc """
  Determines if a webpage should be scraped based on its URL.
  Returns true if the page likely contains marketing/content, false for admin/app pages.
  """
  def should_scrape?(url) when is_binary(url) do
    url
    |> String.downcase()
    |> URI.parse()
    |> extract_path()
    |> should_scrape_path?()
  end

  def should_scrape?(_), do: {:ok, false}

  # Extract path and handle edge cases
  defp extract_path(%URI{path: nil}), do: "/"
  defp extract_path(%URI{path: path}), do: path

  # Check if path should be scraped
  defp should_scrape_path?(path) do
    cond do
      # Always scrape root and basic pages
      path in ["/", "", "/home", "/index"] -> {:ok, true}
      # Skip if contains excluded segments
      contains_excluded_segments?(path) -> {:ok, false}
      # Skip if has excluded file extensions
      has_excluded_extension?(path) -> {:ok, false}
      # Skip if looks like an ID/UUID path
      looks_like_id_path?(path) -> {:ok, false}
      # Default to scraping
      true -> {:ok, true}
    end
  end

  # Common admin/app path segments to exclude
  defp contains_excluded_segments?(path) do
    excluded_segments = [
      # Admin/Management
      "admin",
      "dashboard",
      "manage",
      "control",
      "panel",
      "backend",

      # Authentication
      "login",
      "signin",
      "signup",
      "register",
      "auth",
      "oauth",
      "sso",
      "logout",
      "signout",
      "password",
      "reset",
      "verify",
      "confirm",

      # User Account/App Areas
      "app",
      "account",
      "profile",
      "settings",
      "preferences",
      "config",
      "user",
      "member",
      "my-",
      "portal",
      "console",
      "workspace",

      # API/Technical
      "api",
      "webhook",
      "callback",
      "ws",
      "socket",
      "graphql",
      "rpc",
      "health",
      "status",
      "metrics",
      "monitor",
      "debug",

      # CMS/Internal
      "cms",
      "editor",
      "draft",
      "preview",
      "admin",
      "wp-admin",
      "wp-login",
      "phpmyadmin",
      "cpanel",
      "plesk",

      # E-commerce Internal
      "checkout",
      "cart",
      "payment",
      "billing",
      "invoice",
      "receipt",
      "order",
      "transaction",
      "purchase",

      # Development/Testing
      "test",
      "staging",
      "dev",
      "demo",
      "sandbox",
      "temp",
      "tmp",
      "localhost",
      "127.0.0.1",

      # File Management
      "upload",
      "download",
      "file",
      "files",
      "assets",
      "static",
      "media",
      "images",
      "css",
      "js",
      "fonts",

      # Common Exclusions
      "404",
      "500",
      "error",
      "maintenance",
      "coming-soon",
      "terms",
      "privacy",
      "legal",
      "cookies",
      "gdpr"
    ]

    path_segments = String.split(path, "/", trim: true)

    Enum.any?(path_segments, fn segment ->
      segment_lower = String.downcase(segment)
      Enum.any?(excluded_segments, fn excluded -> segment_lower == excluded end)
    end)
  end

  # File extensions that shouldn't be scraped
  defp has_excluded_extension?(path) do
    excluded_extensions = [
      # Documents
      ".pdf",
      ".doc",
      ".docx",
      ".xls",
      ".xlsx",
      ".ppt",
      ".pptx",

      # Media
      ".jpg",
      ".jpeg",
      ".png",
      ".gif",
      ".svg",
      ".webp",
      ".ico",
      ".mp4",
      ".mov",
      ".avi",
      ".mp3",
      ".wav",

      # Archives
      ".zip",
      ".rar",
      ".tar",
      ".gz",
      ".7z",

      # Code/Data
      ".json",
      ".xml",
      ".csv",
      ".txt",
      ".log",
      ".js",
      ".css",
      ".map",
      ".woff",
      ".woff2",
      ".ttf",

      # Feeds
      ".rss",
      ".atom",
      ".sitemap"
    ]

    path_lower = String.downcase(path)
    Enum.any?(excluded_extensions, &String.ends_with?(path_lower, &1))
  end

  # Check if path looks like an ID (UUIDs, long numbers, etc.)
  defp looks_like_id_path?(path) do
    path_segments = String.split(path, "/", trim: true)

    Enum.any?(path_segments, fn segment ->
      # UUID pattern
      uuid_pattern =
        ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

      # Long number (likely an ID)
      long_number_pattern = ~r/^\d{6,}$/

      # Hash-like string
      hash_pattern = ~r/^[a-f0-9]{16,}$/i

      Regex.match?(uuid_pattern, segment) or
        Regex.match?(long_number_pattern, segment) or
        Regex.match?(hash_pattern, segment)
    end)
  end

  @doc """
  Batch filter URLs - useful for processing lists
  """
  def filter_scrapeable_urls(urls) when is_list(urls) do
    Enum.filter(urls, &should_scrape?/1)
  end

  @doc """
  Get reasons why a URL was excluded (for debugging)
  """
  def exclusion_reason(url) when is_binary(url) do
    path = url |> String.downcase() |> URI.parse() |> extract_path()

    cond do
      contains_excluded_segments?(path) -> {:excluded, :admin_or_app_path}
      has_excluded_extension?(path) -> {:excluded, :file_extension}
      looks_like_id_path?(path) -> {:excluded, :id_path}
      true -> {:included, :content_page}
    end
  end
end
