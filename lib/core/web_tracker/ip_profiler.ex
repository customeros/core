defmodule Core.WebTracker.IPProfiler do
  @moduledoc """
  Handles IP intelligence gathering and validation.
  Coordinates between IPData and Snitcher services for IP validation and company identification.
  """

  alias Core.WebTracker.IpIdentifier

  @doc """
  Gets IP data including location, threat assessment, and mobile carrier info.
  Returns all information from IPData service.
  """
  @spec get_ip_data(String.t()) :: {:ok, map()} | {:error, term()}
  def get_ip_data(ip) do
    ipdata_mod =
      Application.get_env(
        :core,
        Core.WebTracker.BotDetector,
        Core.WebTracker.BotDetector
      )

    case ipdata_mod.verify_ip(ip) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets company information for an IP address using Snitcher.
  Returns a typed response with company details if found.
  """
  def get_company_info(ip) when is_binary(ip) do
    IpIdentifier.identify_ip(ip)
  end

  def get_company_info(_), do: {:error, "IP address must be a string"}
end
