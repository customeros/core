defmodule Core.Utils.LinkedinParser do
  @doc """
  Parses a LinkedIn profile URL and extracts the alias or ID with type detection.

  Examples:
      iex> LinkedInParser.parse_profile_url("https://linkedin.com/in/john-doe")
      {:ok, :alias, "john-doe"}

      iex> LinkedInParser.parse_profile_url("https://linkedin.com/in/ACoAAAX8lzoBNrXd2PoNYW37m_WQddwEAVB8MnI")
      {:ok, :id, "ACoAAAX8lzoBNrXd2PoNYW37m_WQddwEAVB8MnI"}

      iex> LinkedInParser.parse_profile_url("invalid-url")
      {:error, :invalid_url}
  """

  @err_invalid_url {:error, "invalid linkedin url"}

  def parse_contact_url(url) when is_binary(url) do
    url
    |> String.trim()
    |> normalize_url()
    |> extract_identifier()
  end

  def parse_contact_url(_), do: @err_invalid_url

  @doc """
  Determines if a string is a LinkedIn ID or alias.

  LinkedIn IDs typically:
  - Start with "ACoA" or similar patterns
  - Are base64-like strings (alphanumeric + some special chars)
  - Are longer (usually 40+ characters)

  Examples:
      iex> LinkedInParser.detect_type("ACoAAAX8lzoBNrXd2PoNYW37m_WQddwEAVB8MnI")
      :id

      iex> LinkedInParser.detect_type("john-doe-123")
      :alias
  """

  def detect_type(identifier) when is_binary(identifier) do
    if linkedin_id?(identifier) do
      :id
    else
      :alias
    end
  end

  defp normalize_url(url) do
    url = if String.starts_with?(url, "http"), do: url, else: "https://#{url}"

    case URI.parse(url) do
      %URI{host: host, path: path}
      when host in ["linkedin.com", "www.linkedin.com"] ->
        {:ok, path}

      _ ->
        @err_invalid_url
    end
  end

  def extract_identifier({:ok, path}) do
    case String.split(path, "/", trim: true) do
      ["in", identifier | _] when identifier != "" ->
        type = detect_type(identifier)
        {:ok, type, identifier}

      _ ->
        @err_invalid_url
    end
  end

  def extract_identifier({:error, reason}), do: {:error, reason}

  defp linkedin_id?(identifier) do
    String.length(identifier) > 30 and
      (String.starts_with?(identifier, "ACoA") or
         String.starts_with?(identifier, "ACwA") or
         (String.length(identifier) >= 40 and
            Regex.match?(~r/^[A-Za-z0-9_-]+$/, identifier)))
  end
end
