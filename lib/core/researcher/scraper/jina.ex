defmodule Core.Researcher.Scraper.Jina do
  @moduledoc """
  Service for fetching web pages using the Jina API.
  """
  require Logger
  alias Core.Researcher.Errors

  # 45 seconds
  @timeout 45 * 1000

  @doc """
  Fetches a web page async with supervision.
  """
  @spec fetch_page_supervised(String.t()) ::
          Task.t() | {:error, Errors.researcher_error()}
  def fetch_page_supervised(url) when is_binary(url) and url != "" do
    Task.Supervisor.async(
      Core.TaskSupervisor,
      fn -> fetch_page(url) end
    )
  end

  def fetch_page_supervised(""), do: Errors.error(:url_not_provided)
  def fetch_page_supervised(nil), do: Errors.error(:url_not_provided)
  def fetch_page_supervised(_), do: Errors.error(:invalid_url)

  @doc """
  Fetches a web page synchronously using the Jina API.
  """
  @spec fetch_page(String.t()) ::
          {:ok, String.t()}
          | {:error, Errors.researcher_error()}
          | {:error, {:http_error, String.t()}}
  def fetch_page(url) when is_binary(url) do
    with {:ok, config} <- validate_config(),
         request_url <- build_request_url(config.api_path, url),
         response <- make_request(request_url, config.api_key) do
      handle_response(response)
    else
      {:error, reason} -> Errors.error(reason)
    end
  end

  def fetch_page(""), do: Errors.error(:url_not_provided)
  def fetch_page(nil), do: Errors.error(:url_not_provided)
  def fetch_page(_), do: Errors.error(:invalid_url)

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
      {:ok, response} -> response
      {:error, reason} -> Errors.error({:http_error, reason})
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
        Errors.error(:jina_api_key_not_set)

      is_nil(api_path) or api_path == "" ->
        Errors.error(:jina_api_path_not_set)

      true ->
        {:ok, %{api_key: api_key, api_path: api_path}}
    end
  end

  # Pure response handling
  defp handle_response(%Finch.Response{status: 200, body: body}),
    do: {:ok, body}

  defp handle_response(%Finch.Response{status: 402}),
    do: Errors.error(:payment_required)

  defp handle_response(%Finch.Response{status: 422}),
    do: Errors.error(:unprocessable)

  defp handle_response(%Finch.Response{status: status, body: body}) do
    Errors.error({:http_error, "Status: #{status}, Body: #{body}"})
  end

  defp handle_response({:error, reason}), do: Errors.error(reason)
end
