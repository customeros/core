defmodule Core.External.Snitcher.Service do
  @moduledoc """
  Snitcher service integration.
  Handles company identification from IP addresses.
  """
  require Logger

  alias Core.ApiCallLogger.Logger, as: ApiLogger

  @vendor "snitcher"

  @doc """
  Identifies company information from an IP address using Snitcher service.
  """
  @spec identify_ip(String.t()) :: {:ok, map()} | {:error, term()}
  def identify_ip(ip) when is_binary(ip) do
    with {:ok, config} <- get_config(),
         {:ok, response} <- make_request(config, ip) do
      parse_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def identify_ip(_), do: {:error, "IP address must be a string"}

  defp make_request(config, ip) do
    url = "#{config.api_url}/company/find?ip=#{ip}"

    headers = [
      {"Authorization", "Bearer #{config.api_key}"},
      {"Content-Type", "application/json"}
    ]

    :post
    |> Finch.build(url, headers, "")
    |> ApiLogger.request(@vendor)
  end

  defp parse_response(%Finch.Response{status: 200, body: body}) do
    case Jason.decode(body) do
      {:ok, data} ->
        {:ok, %{domain: data["domain"]}}

      {:error, error} ->
        Logger.error("Failed to decode Snitcher response: #{inspect(error)}")
        {:error, :decode_error}
    end
  end

  defp parse_response(%Finch.Response{status: 404}) do
    {:ok, %{domain: nil}}
  end

  defp parse_response(%Finch.Response{status: status, body: body}) do
    Logger.error("Unexpected Snitcher response: status=#{status}, body=#{body}")
    {:error, :service_error}
  end

  defp get_config do
    case Application.get_env(:core, :snitcher) do
      nil ->
        Logger.error("Snitcher configuration is not set")
        {:error, :missing_config}

      config ->
        try do
          api_key = config[:api_key] || raise "SNITCHER_API_KEY is not set"
          api_url = config[:api_url] || raise "Snitcher API URL is not configured"
          {:ok, %{api_key: api_key, api_url: api_url}}
        rescue
          e in RuntimeError ->
            Logger.error(e.message)
            {:error, :invalid_config}
        end
    end
  end
end
