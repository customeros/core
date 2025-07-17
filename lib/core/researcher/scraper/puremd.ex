defmodule Core.Researcher.Scraper.Puremd do
  @moduledoc """
  Service for fetching web pages using the PureMD API.
  """

  require Logger
  require OpenTelemetry.Tracer

  @err_timeout {:error, :timeout}
  @err_invalid_url {:error, :invalid_url}
  @err_url_not_provided {:error, :url_not_provided}
  @err_ratelimit_exceeded {:error, :rate_limit_exceeded}
  @err_empty_response {:error, "empty API response"}
  @err_api_key_not_set {:error, "PureMD API key not set"}
  @err_api_path_not_set {:error, "PureMD API path not set"}

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
  Fetches a web page using the PureMD API.
  """

  def fetch_page(url) when is_binary(url) and byte_size(url) > 0 do
    with {:ok, config} <- validate_config(),
         request_url <- config.api_path <> url,
         {:ok, response} <- make_request(request_url, config.api_key) do
      handle_response(response)
    else
      {:error, %Mint.TransportError{reason: :timeout}} ->
        @err_timeout

      {:error, reason} ->
        {:error, reason}
    end
  end

  def fetch_page(""), do: @err_url_not_provided
  def fetch_page(nil), do: @err_url_not_provided
  def fetch_page(_), do: @err_invalid_url

  defp make_request(request_url, api_key)
       when request_url != "" and api_key != "" do
    :get
    |> Finch.build(
      request_url,
      [
        {"Authorization", "Bearer #{api_key}"},
        {"X-Retain-Images", "none"},
        {"X-With-Links-Summary", "true"}
      ]
    )
    |> Finch.request(Core.Finch,
      receive_timeout: 45_000,
      pool_timeout: 45_000
    )
  end

  defp validate_config do
    Application.get_env(:core, :puremd, [])
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
    api_key = config[:puremd_api_key]
    api_path = config[:puremd_api_path]

    cond do
      api_key == nil || api_key == "" ->
        @err_api_key_not_set

      api_path == nil || api_path == "" ->
        @err_api_path_not_set

      true ->
        {:ok, %{api_key: api_key, api_path: api_path}}
    end
  end

  def handle_response_test(response), do: handle_response(response)

  defp handle_response(%Finch.Response{status: 200, body: body}) do
    if is_binary(body) and String.trim(body) != "" do
      {:ok, body}
    else
      @err_empty_response
    end
  end

  defp handle_response(%Finch.Response{status: status, body: body}) do
    err = "PureMD API error - Status: #{status}, Body: #{body}"
    {:error, err}

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
