defmodule Core.External.Firecrawl.Service do
  @moduledoc """
  Service module for interacting with the Firecrawl API.
  Handles webpage scraping with proper error handling and response processing.
  """

  require Logger

  @base_url "https://api.firecrawl.dev/v1"
  @timeout 30_000

  defp http_client,
    do: Application.get_env(:core, :http_client, Core.External.HttpClient)

  defp api_key do
    Application.get_env(:core, :firecrawl, [])[:api_key] ||
      raise "FIRECRAWL_API_KEY environment variable is not set"
  end

  @doc """
  Fetches and processes a webpage using the Firecrawl API.
  Returns {:ok, content} on success or {:error, reason} on failure.
  """
  def fetch_page(url) do
    Logger.metadata(url: url)
    Logger.info("Fetching page with Firecrawl")

    case http_client().post(
           "#{@base_url}/scrape",
           build_request_body(url),
           build_headers(),
           timeout: @timeout
         ) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, decoded} -> process_successful_response(decoded)
          {:error, reason} -> {:error, {:decode_error, reason}}
        end

      {:ok, %{status: status, body: body}} ->
        decoded_body =
          case Jason.decode(body) do
            {:ok, decoded} -> decoded
            _ -> body
          end
        {:error, {:api_error, status, decoded_body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp build_request_body(url) do
    Jason.encode!(%{
      url: url,
      formats: ["markdown"],
      onlyMainContent: true,
      removeBase64Images: true,
      blockAds: true,
      timeout: @timeout
    })
  end

  defp build_headers do
    [
      {"Authorization", "Bearer #{api_key()}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp process_successful_response(%{"success" => true, "data" => data}) do
    case data do
      %{"markdown" => content} when is_binary(content) and content != "" ->
        {:ok, content}

      _ ->
        {:error, :empty_content}
    end
  end

  defp process_successful_response(response) do
    {:error, {:invalid_format, response}}
  end
end
