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
    with %{api_key: api_key, api_url: api_url} <- get_config(),
         url <- "#{api_url}/#{ip}?api-key=#{api_key}",
         {:ok, response} <- make_request(url),
         {:ok, data} <- parse_response(response) do
      {:ok,
       %{
         ip_address: data["ip"],
         city: data["city"],
         region: data["region"],
         country_code: data["country_code"],
         is_threat: data["threat"]["is_threat"],
         is_mobile: data["carrier"] != nil
       }}
    end
  end

  defp make_request(url) do
    Finch.build(:get, url)
    |> Finch.request(Core.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Finch.Response{status: 400}} ->
        {:error, :invalid_ip}

      {:ok, response} ->
        Logger.error("Unexpected IPData response: #{inspect(response)}")
        {:error, :service_error}

      {:error, error} ->
        Logger.error("IPData request failed: #{inspect(error)}")
        {:error, :request_failed}
    end
  end

  defp parse_response(body) do
    case Jason.decode(body) do
      {:ok, data} ->
        {:ok, data}

      {:error, error} ->
        Logger.error("Failed to decode IPData response: #{inspect(error)}")
        {:error, :decode_error}
    end
  end

  defp get_config do
    case Application.get_env(:core, :ipdata) do
      nil ->
        Logger.error("IPData configuration is not set")
        {:error, :missing_config}

      config ->
        with {:ok, api_key} <- get_config_value(config, :api_key, "IPDATA_API_KEY is not set"),
             {:ok, api_url} <-
               get_config_value(config, :api_url, "IPData API URL is not configured") do
          %{api_key: api_key, api_url: api_url}
        end
    end
  end

  defp get_config_value(config, key, error_message) do
    case config[key] do
      nil ->
        Logger.error(error_message)
        {:error, :missing_config}

      value ->
        {:ok, value}
    end
  end
end
