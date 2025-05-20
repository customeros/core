defmodule Core.External.Jina.Service do
  @moduledoc """
  Service for fetching web pages using the Jina API.
  """

  @error_payment_required {:error, :payment_required}
  @error_unprocessable {:error, :unprocessable}

  @doc """
  Fetches a web page using the Jina API.
  """
  def fetch_page(nil), do: {:error, "url cannot be nil"}
  def fetch_page(""), do: {:error, "url cannot be empty string"}
  def fetch_page(url) when not is_binary(url), do: {:error, "url is invalid"}

  def fetch_page(url) when is_binary(url) do
    with {:ok, config} <- validate_config(),
         request_url <- config.jina_api_path <> url,
         {:ok, response} <- make_request(request_url, config.jina_api_key) do
      handle_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp make_request(request_url, api_key) when request_url != "" and api_key != "" do
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
      receive_timeout: 15_000,
      pool_timeout: 15_000
    )
  end

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
      api_key == nil || api_key == "" ->
        {:error, "jina API key not set"}

      api_path == nil || api_path == "" ->
        {:error, "jina API path not set"}

      true ->
        {:ok, %{jina_api_key: api_key, jina_api_path: api_path}}
    end
  end

  defp handle_response(%Finch.Response{status: 200, body: body}), do: {:ok, body}
  defp handle_response(%Finch.Response{status: 402}), do: @error_payment_required
  defp handle_response(%Finch.Response{status: 422}), do: @error_unprocessable
  defp handle_response(%Finch.Response{status: status}), do: {:error, "error code: #{status}"}
end
