defmodule Core.Researcher.Scraper.Firecrawl do
  @moduledoc """
  Service for fetching web pages using the Firecrawl API.
  """

  require OpenTelemetry.Tracer

  # 45 seconds
  @timeout 45 * 1000

  @err_firecrawl_api_key_not_set {:error, "firecrawl API key not set"}
  @err_firecrawl_api_path_not_set {:error, "firecrawl API path not set"}
  @err_empty_response {:error, "empty API response"}
  @err_invalid_api_response {:error, "invalid API response format"}
  @err_invalid_url {:error, :invalid_url}
  @err_ratelimit_exceeded {:error, :rate_limit_exceeded}
  @err_unable_to_decode_response {:error, "unable to decode response"}
  @err_url_not_provided {:error, :url_not_provided}

  @doc """
  Fetches a web page async with supervision.
  """
  def fetch_page_supervised(url) do
    ctx = OpenTelemetry.Ctx.get_current()
    Task.Supervisor.async(
      Core.TaskSupervisor,
      fn ->
        OpenTelemetry.Ctx.attach(ctx)
        fetch_page(url)
      end
    )
  end

  @doc """
  Fetches a web page synchronously using the Firecrawl API.
  """
  def fetch_page(url) when is_binary(url) and byte_size(url) > 0 do
    with {:ok, config} <- validate_config(),
         request_body <- build_request_body(url),
         response <- make_request(config.api_path, request_body, config.api_key) do
      handle_response(response)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def fetch_page(""), do: @err_url_not_provided
  def fetch_page(nil), do: @err_url_not_provided
  def fetch_page(_), do: @err_invalid_url

  # Private functions

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

  defp make_request(api_path, request_body, api_key)
       when is_binary(api_path) and api_path != "" and
              is_binary(request_body) and request_body != "" and
              is_binary(api_key) and api_key != "" do
    case Finch.build(
           :post,
           api_path,
           [
             {"Authorization", "Bearer #{api_key}"},
             {"Content-Type", "application/json"}
           ],
           request_body
         )
         |> Finch.request(Core.Finch,
           receive_timeout: @timeout,
           pool_timeout: @timeout
         ) do
      {:ok, response} -> response
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_config do
    Application.get_env(:core, :firecrawl, [])
    |> normalize_config()
    |> validate_api_credentials()
  end

  defp normalize_config(config) do
    cond do
      is_list(config) -> Enum.into(config, %{})
      is_map(config) -> config
      true -> %{}
    end
  end

  defp validate_api_credentials(config) do
    api_key = config[:firecrawl_api_key]

    api_path =
      config[:firecrawl_api_path] || "https://api.firecrawl.dev/v1/scrape"

    cond do
      is_nil(api_key) or api_key == "" ->
        @err_firecrawl_api_key_not_set

      is_nil(api_path) or api_path == "" ->
        @err_firecrawl_api_path_not_set

      true ->
        {:ok, %{api_key: api_key, api_path: api_path}}
    end
  end

  # Pure response handling
  def handle_response_test(response), do: handle_response(response)

  defp handle_response(%Finch.Response{status: 200, body: body}) do
    case Jason.decode(body) do
      {:ok, %{"success" => true, "data" => %{"markdown" => content}}}
      when is_binary(content) and content != "" ->
        {:ok, content}

      {:ok, %{"success" => true, "data" => _}} ->
        @err_empty_response

      {:ok, _decoded} ->
        @err_invalid_api_response

      {:error, _reason} ->
        @err_unable_to_decode_response
    end
  end

  defp handle_response(%Finch.Response{status: status, body: body}) do
    case status do
      429 ->
        @err_ratelimit_exceeded

      _ ->
        decoded_body =
          case Jason.decode(body) do
            {:ok, decoded} -> decoded
            _ -> body
          end

        err = "Status: #{status}, Body: #{inspect(decoded_body)}"
        {:error, err}
    end
  end

  defp handle_response({:error, reason}), do: {:error, reason}
end
