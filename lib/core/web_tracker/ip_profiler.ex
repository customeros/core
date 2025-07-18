defmodule Core.WebTracker.IPProfiler do
  @moduledoc """
  Handles IP intelligence gathering and validation.
  Coordinates between IPData and Snitcher services for IP validation and company identification.
  """

  require Logger
  require OpenTelemetry.Tracer

  alias Core.Repo
  alias Core.Utils.IdGenerator
  alias Core.WebTracker.IpIdentifier
  alias Core.WebTracker.IpIdentifier.IpIntelligence

  @doc """
  Gets IP data including location, threat assessment, and mobile carrier info.
  First checks for existing IP intelligence record, if not found calls IPData service.
  """
  @spec get_ip_data(String.t()) :: {:ok, map()} | {:error, term()}
  def get_ip_data(ip) do
    OpenTelemetry.Tracer.with_span "ip_profiler.get_ip_data" do
      case IpIntelligence.get_by_ip(ip) do
        {:ok, record} when not is_nil(record) ->
          # Return data from existing record
          {:ok,
           %{
             ip_address: record.ip,
             city: record.city,
             region: record.region,
             country_code: record.country,
             is_threat: record.has_threat,
             is_mobile: record.is_mobile
           }}

        {:ok, nil} ->
          # No existing record, fetch from IPData
          fetch_from_ipdata(ip)

        {:error, reason} ->
          Logger.error("Failed to query IP intelligence: #{inspect(reason)}")
          fetch_from_ipdata(ip)
      end
    end
  end

  @doc """
  Gets company information for an IP address using Snitcher.
  Returns a typed response with company details if found.
  """
  def get_company_info(ip)
      when is_binary(ip) do
    case IpIntelligence.get_domain_by_ip(ip) do
      {:ok, domain} ->
        {:ok,
         %{
           ip: ip,
           domain: domain,
           company: %{}
         }}

      _ ->
        IpIdentifier.identify_ip(ip)
    end
  end

  def get_company_info(_, _), do: {:error, "IP address must be a string"}

  # Private functions

  defp fetch_from_ipdata(ip) do
    ipdata_mod =
      Application.get_env(
        :core,
        Core.WebTracker.IpLocator,
        Core.WebTracker.IpLocator
      )

    case ipdata_mod.verify_ip(ip) do
      {:ok, data} ->
        update_ip_intelligence(ip, data)
        {:ok, data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_ip_intelligence(ip, data) do
    attrs = %{
      is_mobile: data.is_mobile,
      city: data.city,
      region: data.region,
      country: data.country_code,
      has_threat: data.is_threat,
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case IpIntelligence.get_by_ip(ip) do
      {:ok, nil} ->
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
            Logger.error(
              "Failed to create IP intelligence record: #{inspect(changeset.errors)}"
            )

            :error
        end

      {:ok, record} ->
        record
        |> IpIntelligence.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, _record} ->
            :ok

          {:error, changeset} ->
            Logger.error(
              "Failed to update IP intelligence record: #{inspect(changeset.errors)}"
            )

            :error
        end

      {:error, reason} ->
        Logger.error(
          "Failed to query IP intelligence record: #{inspect(reason)}"
        )

        :error
    end
  end
end
