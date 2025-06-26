defmodule Core.WebTracker.IpIdentifier do
  @moduledoc """
  Integrates with the Snitcher API for IP-based company identification.

  This module manages:
  * IP address to company identification
  * API request handling and authentication
  * Response parsing and validation
  * Error handling and logging
  * Configuration management

  It provides a service interface to the Snitcher API, allowing
  the system to identify companies based on IP addresses. The
  module handles API authentication, request formatting, response
  parsing, and proper error handling for various failure scenarios.
  """

  require Logger
  require OpenTelemetry.Tracer

  alias Core.Logger.ApiLogger, as: ApiLogger
  alias Core.WebTracker.IpIdentifier.SnitcherPayload
  alias Core.WebTracker.IpIdentifier.IpIntelligence
  alias Core.Repo
  alias Core.Utils.IdGenerator
  alias Core.Utils.Tracing

  @vendor "snitcher"

  def identify_ip(ip, default_domain \\ nil)

  def identify_ip(ip, default_domain)
      when is_binary(ip) and byte_size(ip) > 0 do
    with {:ok, config} <- get_config(),
         {:ok, response} <- make_request(config, ip),
         {:ok, snitcher_response} <- parse_response(response) do
      update_ip_intelligence_with_snitcher_response(
        ip,
        snitcher_response,
        default_domain
      )

      {:ok, snitcher_response}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def identify_ip(_, _), do: {:error, "IP address must be a string"}

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

  defp parse_response(%Finch.Response{status: status, body: body})
       when status in [200, 404] do
    case Jason.decode(body) do
      {:ok, data} ->
        SnitcherPayload.parse_response(data)

      {:error, error} ->
        Logger.error("Failed to decode Snitcher response: #{inspect(error)}")
        {:error, :decode_error}
    end
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

          api_url =
            config[:api_url] || raise "Snitcher API URL is not configured"

          {:ok, %{api_key: api_key, api_url: api_url}}
        rescue
          e in RuntimeError ->
            Logger.error(e.message)
            {:error, :invalid_config}
        end
    end
  end

  defp update_ip_intelligence_with_snitcher_response(_ip, %{company: nil}, _),
    do: :ok

  defp update_ip_intelligence_with_snitcher_response(
         ip,
         %{
           company: %{domain: company_domain},
           domain: domain
         },
         default_domain
       )
       when is_binary(company_domain) do
    OpenTelemetry.Tracer.with_span "ip_identifier.update_ip_intelligence_with_snitcher_response" do
      attrs = %{
        domain: domain || default_domain,
        domain_source:
          case domain do
            nil -> :snitcher
            _ -> :tracker
          end,
        updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      case IpIntelligence.get_by_ip(ip) do
        {:ok, nil} ->
          # Create new record with company data
          %IpIntelligence{}
          |> IpIntelligence.changeset(
            Map.merge(attrs, %{
              id: IdGenerator.generate_id_21(IpIntelligence.id_prefix()),
              ip: ip
            })
          )
          |> Repo.insert()
          |> case do
            {:ok, _record} ->
              :ok

            {:error, changeset} ->
              Tracing.error(changeset.errors)

              Logger.error(
                "Failed to create IP intelligence record with company data: #{inspect(changeset.errors)}"
              )

              :error
          end

        {:ok, record} ->
          # Update existing record with company data
          record
          |> IpIntelligence.changeset(attrs)
          |> Repo.update()
          |> case do
            {:ok, _record} ->
              :ok

            {:error, changeset} ->
              Tracing.error(changeset.errors)

              Logger.error(
                "Failed to update IP intelligence record with company data: #{inspect(changeset.errors)}"
              )

              :error
          end

        {:error, reason} ->
          Tracing.error(reason)

          Logger.error(
            "Failed to query IP intelligence record: #{inspect(reason)}"
          )

          :error
      end
    end
  end
end
