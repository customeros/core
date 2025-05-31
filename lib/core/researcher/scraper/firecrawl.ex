defmodule Core.Researcher.Scraper.Firecrawl do
  @moduledoc """
  Service for fetching web pages using the Firecrawl API.
  """
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
  Fetches a web page synchronously using the Firecrawl API.
  """
  @spec fetch_page(String.t()) ::
          {:ok, String.t()}
          | {:error, Errors.researcher_error()}
          | {:error, {:http_error, String.t()}}
  def fetch_page(url) when is_binary(url) do
    with {:ok, config} <- validate_config(),
         request_body <- build_request_body(url),
         response <- make_request(config.api_path, request_body, config.api_key) do
      handle_response(response)
    else
      {:error, reason} -> Errors.error(reason)
    end
  end

  def fetch_page(""), do: Errors.error(:url_not_provided)
  def fetch_page(nil), do: Errors.error(:url_not_provided)
  def fetch_page(_), do: Errors.error(:invalid_url)

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
      {:error, reason} -> Errors.error({:http_error, reason})
    end
  end

  # Pure configuration validation
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
        Errors.error(:firecrawl_api_key_not_set)

      is_nil(api_path) or api_path == "" ->
        Errors.error(:firecrawl_api_path_not_set)

      true ->
        {:ok, %{api_key: api_key, api_path: api_path}}
    end
  end

  # Pure response handling
  defp handle_response(%Finch.Response{status: 200, body: body}) do
    case Jason.decode(body) do
      {:ok, %{"success" => true, "data" => %{"markdown" => content}}}
      when is_binary(content) and content != "" ->
        {:ok, content}

      {:ok, %{"success" => true, "data" => _}} ->
        Errors.error(:empty_content)

      {:ok, decoded} ->
        Errors.error({:invalid_format, decoded})

      {:error, reason} ->
        Errors.error({:decode_error, reason})
    end
  end

  defp handle_response(%Finch.Response{status: 402}),
    do: Errors.error(:payment_required)

  defp handle_response(%Finch.Response{status: 422}),
    do: Errors.error(:unprocessable)

  defp handle_response(%Finch.Response{status: status, body: body}) do
    decoded_body =
      case Jason.decode(body) do
        {:ok, decoded} -> decoded
        _ -> body
      end

    Errors.error(
      {:http_error, "Status: #{status}, Body: #{inspect(decoded_body)}"}
    )
  end

  defp handle_response({:error, reason}), do: Errors.error(reason)
end
