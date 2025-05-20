defmodule Core.External.Snitcher.Service do
  @moduledoc """
  Snitcher service integration.
  Handles company identification from IP addresses.
  """

  require Logger

  @doc """
  Identifies company information from an IP address using Snitcher service.
  """
  @spec identify_ip(String.t()) :: {:ok, map()} | {:error, term()}
  def identify_ip(ip) do
    config = get_config()
    api_key = config.api_key
    api_url = config.api_url

    case HTTPoison.post(
           "#{api_url}/company/find",
           "",
           [
             {"Authorization", "Bearer #{api_key}"},
             {"Content-Type", "application/json"}
           ],
           params: [ip: ip]
         ) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} ->
            {:ok, %{
              domain: data["domain"]
            }}

          {:error, error} ->
            Logger.error("Failed to decode Snitcher response: #{inspect(error)}")
            {:error, :decode_error}
        end

      {:ok, %{status_code: 404}} ->
        {:ok, %{domain: nil}}

      {:ok, response} ->
        Logger.error("Unexpected Snitcher response: #{inspect(response)}")
        {:error, :service_error}

      {:error, error} ->
        Logger.error("Snitcher request failed: #{inspect(error)}")
        {:error, :request_failed}
    end
  end

  defp get_config do
    case Application.get_env(:core, :snitcher) do
      nil -> raise "Snitcher configuration is not set"
      config ->
        api_key = config[:api_key] || raise "SNITCHER_API_KEY is not set"
        api_url = config[:api_url] || raise "Snitcher API URL is not configured"
        %{api_key: api_key, api_url: api_url}
    end
  end
end
