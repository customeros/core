defmodule Core.External.IPData.Service do
  @moduledoc """
  IPData service integration.
  Handles IP address verification and intelligence gathering.
  """

  require Logger

  @doc """
  Verifies an IP address using IPData service.
  Returns information about the IP including:
  - Location (city, region, country)
  - Threat assessment
  - Mobile carrier info
  """
  @spec verify_ip(String.t()) :: {:ok, map()} | {:error, term()}
  def verify_ip(ip) do
    config = get_config()
    api_key = config.api_key
    api_url = config.api_url

    case HTTPoison.get("#{api_url}/#{ip}?api-key=#{api_key}") do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} ->
            {:ok, %{
              ip_address: data["ip"],
              city: data["city"],
              region: data["region"],
              country_code: data["country_code"],
              is_threat: data["threat"]["is_threat"],
              is_mobile: data["carrier"] != nil
            }}

          {:error, error} ->
            Logger.error("Failed to decode IPData response: #{inspect(error)}")
            {:error, :decode_error}
        end

      {:ok, %{status_code: 400}} ->
        {:error, :invalid_ip}

      {:ok, response} ->
        Logger.error("Unexpected IPData response: #{inspect(response)}")
        {:error, :service_error}

      {:error, error} ->
        Logger.error("IPData request failed: #{inspect(error)}")
        {:error, :request_failed}
    end
  end

  defp get_config do
    case Application.get_env(:core, :ipdata) do
      nil -> raise "IPData configuration is not set"
      config ->
        api_key = config[:api_key] || raise "IPDATA_API_KEY is not set"
        api_url = config[:api_url] || raise "IPData API URL is not configured"
        %{api_key: api_key, api_url: api_url}
    end
  end
end
