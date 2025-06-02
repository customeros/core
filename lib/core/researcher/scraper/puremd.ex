defmodule Core.Researcher.Scraper.Puremd do
  @moduledoc """
  Service for fetching web pages using the PureMD API.
  """

  require Logger
  alias Core.Researcher.Errors

  @doc """
  Fetches a web page async with supervision.
  """
  @spec fetch_page_supervised(String.t()) :: Task.t()
  def fetch_page_supervised(url) do
    Task.Supervisor.async(
      Core.TaskSupervisor,
      fn -> fetch_page(url) end
    )
  end

  @doc """
  Fetches a web page using the PureMD API.
  """

  @spec fetch_page(String.t()) ::
          {:ok, String.t()}
          | {:error, Errors.researcher_error()}
          | {:error, {:http_error, String.t()}}
  def fetch_page(url) when is_binary(url) do
    with {:ok, config} <- validate_config(),
         request_url <- config.api_path <> url,
         {:ok, response} <- make_request(request_url, config.api_key) do
      handle_response(response)
    else
      {:error, reason} -> Errors.error(reason)
    end
  end

  def fetch_page(""), do: Errors.error(:url_not_provided)
  def fetch_page(nil), do: Errors.error(:url_not_provided)
  def fetch_page(_), do: Errors.error(:invalid_url)

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
        Errors.error(:puremd_api_key_not_set)

      api_path == nil || api_path == "" ->
        Errors.error(:puremd_api_path_not_set)

      true ->
        {:ok, %{api_key: api_key, api_path: api_path}}
    end
  end

  defp handle_response(%Finch.Response{status: 200, body: body}),
    do: {:ok, body}

  defp handle_response(%Finch.Response{status: status, body: body}) do
    Logger.error("PureMD API error - Status: #{status}, Body: #{body}")
    {:error, :http_error}
  end
end
