defmodule Core.WebTracker.OriginTenantMapper do
  @moduledoc """
  Manages the mapping between whitelisted origins and their corresponding tenants.
  """

  # TODO: Move this to db later
  @whitelisted_origins %{
    "getkanda.com" => "getkandacom",
    "dashboard.kanda.co.uk" => "getkandacom",
    "infinity.co" => "infinityco",
    "nuso.cloud" => "nusocloud",
    "nusocloud.eu" => "nusocloud",
    "customeros.ai" => "customerosai"
  }

  @doc """
  Checks if given origin is whitelisted and returns its associated tenant.
  The origin can be provided with or without http:// or https:// prefix.
  """
  @spec get_tenant_for_origin(String.t()) :: {:ok, String.t()} | {:error, :origin_not_configured}
  def get_tenant_for_origin(origin) when is_binary(origin) do
    normalized_origin = normalize_origin(origin)
    case Map.get(@whitelisted_origins, normalized_origin) do
      nil -> {:error, :origin_not_configured}
      tenant -> {:ok, tenant}
    end
  end

  def get_tenant_for_origin(_), do: {:error, :invalid_origin}

  @spec normalize_origin(String.t()) :: String.t()
  defp normalize_origin(origin) do
    origin
    |> String.trim()
    |> String.downcase()
    |> String.replace_prefix("https://", "")
    |> String.replace_prefix("http://", "")
    |> String.replace_prefix("www.", "")
    |> String.trim("/")
    |> String.trim()
  end

  @doc """
  Returns true if the origin is in the whitelist.
  """
  @spec whitelisted?(String.t()) :: boolean()
  def whitelisted?(origin) when is_binary(origin) do
    case get_tenant_for_origin(origin) do
      {:ok, _tenant} -> true
      _ -> false
    end
  end

  def whitelisted?(_), do: false
end
