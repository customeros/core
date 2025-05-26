defmodule Core.External.Firecrawl.TestHelper do
  @moduledoc """
  Helper module for testing Firecrawl API integration.
  Provides test data and helper functions for Firecrawl tests.

  ## Usage

      # In your test file
      use Core.DataCase
      import Core.External.Firecrawl.TestHelper

      test "fetches page successfully" do
        # Use test_url() for consistent test URLs
        assert {:ok, _content} = Service.fetch_page(test_url())
      end
  """

  @doc """
  Returns a test URL for Firecrawl tests.
  """
  def test_url, do: "https://example.com"

  @doc """
  Returns a valid test response body for Firecrawl tests.
  """
  def valid_response_body do
    Jason.encode!(%{
      "success" => true,
      "data" => %{
        "markdown" => "# Test Content\n\nThis is a test page."
      }
    })
  end

  @doc """
  Returns an error response body for Firecrawl tests.
  """
  def error_response_body do
    Jason.encode!(%{
      "error" => "Invalid URL"
    })
  end

  @doc """
  Returns test headers for Firecrawl API requests.
  """
  def test_headers do
    [
      {"Authorization", "Bearer test-api-key"},
      {"Content-Type", "application/json"}
    ]
  end

  @doc """
  Returns a test request body for Firecrawl API requests.
  """
  def test_request_body(url) do
    Jason.encode!(%{
      url: url,
      formats: ["markdown"],
      onlyMainContent: true,
      removeBase64Images: true,
      blockAds: true,
      timeout: 30_000
    })
  end

  @doc """
  Runs an integration test against the Firecrawl API.
  Returns {:ok, content} on success or {:error, reason} on failure.

  ## Examples

      iex> run_integration_test()
      {:ok, "# Test Content\\n\\nThis is a test page."}
  """
  def run_integration_test do
    case Core.External.Firecrawl.Service.fetch_page(test_url()) do
      {:ok, content} ->
        IO.puts("✅ Firecrawl API test successful!")
        IO.puts("\nContent preview:")
        IO.puts(String.slice(content, 0..200) <> "...")
        {:ok, content}

      {:error, reason} ->
        IO.puts("❌ Firecrawl API test failed:")
        IO.puts(reason)
        {:error, reason}
    end
  end
end
