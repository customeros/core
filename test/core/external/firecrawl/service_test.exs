defmodule Core.External.Firecrawl.ServiceTest do
  use Core.DataCase, async: true
  import Mox
  import Core.External.Firecrawl.TestHelper

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Define the mock for HttpClient
  @http_client_mock Core.External.HttpClient.Mock

  setup do
    # Set a test API key for all tests
    Application.put_env(:core, :firecrawl, api_key: "test-api-key")
    :ok
  end

  describe "fetch_page/1" do
    test "successfully fetches and processes a webpage" do
      test_url = test_url()
      expect_successful_request(test_url)
      assert {:ok, content} = Core.External.Firecrawl.Service.fetch_page(test_url)
      assert content == "# Test Content\n\nThis is a test page."
    end

    test "handles API error response" do
      test_url = test_url()
      expect_error_response(test_url, 400)
      assert {:error, {:api_error, 400, _}} = Core.External.Firecrawl.Service.fetch_page(test_url)
    end

    test "handles empty content response" do
      test_url = test_url()
      expect_empty_content_response(test_url)
      assert {:error, :empty_content} = Core.External.Firecrawl.Service.fetch_page(test_url)
    end

    test "handles unexpected response format" do
      test_url = test_url()
      expect_invalid_format_response(test_url)
      assert {:error, :empty_content} = Core.External.Firecrawl.Service.fetch_page(test_url)
    end

    test "handles HTTP client errors" do
      test_url = test_url()
      expect_http_error(test_url, :timeout)
      assert {:error, {:request_failed, :timeout}} = Core.External.Firecrawl.Service.fetch_page(test_url)
    end

    test "handles network errors" do
      test_url = test_url()
      expect_http_error(test_url, :econnrefused)
      assert {:error, {:request_failed, :econnrefused}} = Core.External.Firecrawl.Service.fetch_page(test_url)
    end

    test "handles JSON decode errors" do
      test_url = test_url()
      expect_invalid_json_response(test_url)
      assert {:error, {:decode_error, _}} = Core.External.Firecrawl.Service.fetch_page(test_url)
    end
  end

  defp expect_successful_request(url) do
    expect(@http_client_mock, :post, fn request_url, body, headers, opts ->
      assert request_url == "https://api.firecrawl.dev/v1/scrape"
      assert headers == test_headers()
      assert opts[:timeout] == 30_000
      assert_valid_request_body(body, url)
      {:ok, %{status: 200, body: valid_response_body()}}
    end)
  end

  defp expect_error_response(_url, status) do
    expect(@http_client_mock, :post, fn _url, _body, _headers, _opts ->
      {:ok, %{status: status, body: error_response_body()}}
    end)
  end

  defp expect_empty_content_response(_url) do
    expect(@http_client_mock, :post, fn _url, _body, _headers, _opts ->
      {:ok,
       %{
         status: 200,
         body:
           Jason.encode!(%{
             "success" => true,
             "data" => %{
               "markdown" => ""
             }
           })
       }}
    end)
  end

  defp expect_invalid_format_response(_url) do
    expect(@http_client_mock, :post, fn _url, _body, _headers, _opts ->
      {:ok,
       %{
         status: 200,
         body: Jason.encode!(%{"success" => true, "data" => %{}})
       }}
    end)
  end

  defp expect_http_error(_url, reason) do
    expect(@http_client_mock, :post, fn _url, _body, _headers, _opts ->
      {:error, reason}
    end)
  end

  defp expect_invalid_json_response(_url) do
    expect(@http_client_mock, :post, fn _url, _body, _headers, _opts ->
      {:ok, %{status: 200, body: "invalid json"}}
    end)
  end

  defp assert_valid_request_body(body, url) do
    {:ok, decoded_body} = Jason.decode(body)
    assert decoded_body["url"] == url
    assert decoded_body["formats"] == ["markdown"]
    assert decoded_body["onlyMainContent"] == true
    assert decoded_body["removeBase64Images"] == true
    assert decoded_body["blockAds"] == true
  end
end
