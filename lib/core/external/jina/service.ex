defmodule Core.External.Jina.Service do
  @error_payment_required {:error, :payment_required}
  @error_unprocessable {:error, :unprocessable}

  def fetch_page(url) do
    with {:ok, config} <- validate_config(),
         request_url = config.jina_api_path <> url,
         {:ok, status_code, _headers, client_ref} <-
           make_request(request_url, config.jina_api_key),
         {:ok, body} <- read_resp(client_ref),
         {:ok, body} <- handle_response(status_code, body) do
      {:ok, body}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp make_request(request_url, api_key) do
    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"X-Retain-Images", "none"},
      {"X-With-Links-Summary", "true"}
    ]

    options = [
      timeout: 15_000,
      recv_timeout: 15_000,
      follow_redirect: true
    ]

    :hackney.request(:get, request_url, headers, "", options)
  end

  defp read_resp(client_ref) do
    case :hackney.body(client_ref) do
      {:ok, body} -> {:ok, body}
      {:error, reason} -> {:error, "error reading response body: #{inspect(reason)}"}
    end
  end

  defp validate_config do
    config = Application.get_env(:core, :jina, [])
    # Convert config to map for consistent access
    config_map =
      cond do
        is_list(config) -> Enum.into(config, %{})
        is_map(config) -> config
        true -> %{}
      end

    api_key = config_map[:jina_api_key]
    api_path = config_map[:jina_api_path]

    cond do
      api_key == nil || api_key == "" ->
        {:error, "jina API key not set"}

      api_path == nil || api_path == "" ->
        {:error, "jina API path not set"}

      true ->
        {:ok, %{jina_api_key: api_key, jina_api_path: api_path}}
    end
  end

  defp handle_response(200, body), do: {:ok, body}
  defp handle_response(402, _body), do: @error_payment_required
  defp handle_response(422, _body), do: @error_unprocessable
  defp handle_response(status_code, _body), do: {:error, "error code: #{status_code}"}
end
