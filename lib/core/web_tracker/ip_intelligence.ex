defmodule Core.WebTracker.IPIntelligence do
  @moduledoc """
  Handles IP intelligence gathering and validation.
  Coordinates between IPData and Snitcher services for IP validation and company identification.
  """

  alias Core.External.IPData.Service, as: IPData
  alias Core.External.Snitcher.Service, as: Snitcher

  @doc """
  Validates if an IP address is a threat using IPData service.
  """
  @spec check_ip_threat(String.t()) :: :ok | {:error, :threat}
  def check_ip_threat(ip) do
    case IPData.verify_ip(ip) do
      {:ok, %{is_threat: true}} -> {:error, :threat}
      {:ok, _} -> :ok
      {:error, _} -> :ok  # Be lenient on service errors
    end
  end

  @doc """
  Gets company information for an IP address using Snitcher.
  """
  @spec get_company_info(String.t()) :: {:ok, map()} | {:error, term()}
  def get_company_info(ip) do
    Snitcher.identify_ip(ip)
  end
end
