defmodule Core.WebTracker.IPIntelligence do
  @moduledoc """
  Handles IP intelligence gathering and validation.
  Coordinates between IPData and Snitcher services for IP validation and company identification.
  """

  alias Core.External.IPData.Service, as: IPData
  alias Core.External.Snitcher.Service, as: Snitcher
  alias Core.External.Snitcher.Types

  @doc """
  Gets IP data including location, threat assessment, and mobile carrier info.
  Returns all information from IPData service.
  """
  @spec get_ip_data(String.t()) :: {:ok, map()} | {:error, term()}
  def get_ip_data(ip) do
    case IPData.verify_ip(ip) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets company information for an IP address using Snitcher.
  Returns a typed response with company details if found.
  """
  @spec get_company_info(String.t()) :: {:ok, Types.t()} | {:error, term()}
  def get_company_info(ip) when is_binary(ip) do
    Snitcher.identify_ip(ip)
  end

  def get_company_info(_), do: {:error, "IP address must be a string"}
end
