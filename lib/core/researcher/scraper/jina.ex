defmodule Core.Researcher.Scraper.Jina do
  @moduledoc """
  Service for fetching web pages using the Jina API.
  """
  require Logger
  require OpenTelemetry.Tracer

  @err_timeout {:error, :timeout}
  @err_invalid_url {:error, :invalid_url}
  @err_url_not_provided {:error, :url_not_provided}
  @err_ratelimit_exceeded {:error, :rate_limit_exceeded}
  @err_empty_response {:error, "empty API response"}
  @err_api_key_not_set {:error, "Jina API key not set"}
  @err_api_path_not_set {:error, "Jina API path not set"}

  # 45 seconds
  @timeout 45 * 1000

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
  Fetches a web page synchronously using the Jina API.
  """
  def fetch_page(url) when is_binary(url) and byte_size(url) > 0 do
    with {:ok, config} <- validate_config(),
         request_url <- build_request_url(config.api_path, url),
         response <- make_request(request_url, config.api_key) do
      handle_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_page(""), do: @err_url_not_provided
  def fetch_page(nil), do: @err_url_not_provided
  def fetch_page(_), do: @err_invalid_url

  # Private functions
  defp build_request_url(api_path, url), do: api_path <> url

  defp make_request(request_url, api_key)
       when is_binary(request_url) and request_url != "" and
              is_binary(api_key) and api_key != "" do
    case Finch.build(
           :get,
           request_url,
           [
             {"Authorization", "Bearer #{api_key}"},
             {"X-Retain-Images", "none"},
             {"X-With-Links-Summary", "true"}
           ]
         )
         |> Finch.request(Core.Finch,
           receive_timeout: @timeout,
           pool_timeout: @timeout
         ) do
      {:ok, response} ->
        response

      {:error, %Mint.TransportError{reason: :timeout}} ->
        @err_timeout

      {:error, reason} ->
        err = "Jina API request failed: #{inspect(reason)}"
        {:error, err}
    end
  end

  # Pure configuration validation
  defp validate_config do
    Application.get_env(:core, :jina, [])
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
    api_key = config[:jina_api_key]
    api_path = config[:jina_api_path]

    cond do
      is_nil(api_key) or api_key == "" ->
        @err_api_key_not_set

      is_nil(api_path) or api_path == "" ->
        @err_api_path_not_set

      true ->
        {:ok, %{api_key: api_key, api_path: api_path}}
    end
  end

  # Pure response handling
  def handle_response_test(response), do: handle_response(response)

  defp handle_response(%Finch.Response{status: 200, body: body}) do
    if is_binary(body) and String.trim(body) != "" do
      {:ok, body}
    else
      @err_empty_response
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
