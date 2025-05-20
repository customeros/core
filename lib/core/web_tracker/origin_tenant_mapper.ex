defmodule Core.WebTracker.OriginTenantMapper do
  @moduledoc """
  Manages the mapping between whitelisted origins and their corresponding tenants.
  """

  # TODO: Move this to db later
  @whitelisted_origins %{
    "getkanda.com" => "kandacouk",
    "dashboard.kanda.co.uk" => "kandacouk",
    "infinity.co" => "infinityco",
    "nuso.cloud" => "nusocloud",
    "nusocloud.eu" => "nusocloud"
  }

  @doc """
  Checks if an origin is whitelisted and returns its associated tenant.
  """
  def get_tenant_for_origin(origin) when is_binary(origin) do
    case Map.get(@whitelisted_origins, origin) do
      nil -> {:error, :origin_not_configured}
      tenant -> {:ok, tenant}
    end
  end

  def get_tenant_for_origin(_), do: {:error, :invalid_origin}

  @doc """
  Returns true if the origin is in the whitelist.
  """
  def whitelisted?(origin) when is_binary(origin) do
    case get_tenant_for_origin(origin) do
      {:ok, _tenant} -> true
      _ -> false
    end
  end

  def whitelisted?(_), do: false
end
