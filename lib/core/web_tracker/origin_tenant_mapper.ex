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
  If exact match is not found, checks if the origin is a subdomain of a whitelisted root domain.
  """
  @spec get_tenant_for_origin(String.t()) ::
          {:ok, String.t()} | {:error, :origin_not_configured | :invalid_origin}
  def get_tenant_for_origin(origin) when is_binary(origin) do
    cleaned_origin = clean_origin(origin)

    case Map.get(@whitelisted_origins, cleaned_origin) do
      nil ->
        # If exact match not found, try to get root domain
        case Core.Utils.DomainValidator.parse_root_and_subdomain(cleaned_origin) do
          {:ok, root_domain, _subdomain} ->
            case Map.get(@whitelisted_origins, root_domain) do
              nil -> {:error, :origin_not_configured}
              tenant -> {:ok, tenant}
            end

          {:error, _} ->
            {:error, :origin_not_configured}
        end

      tenant ->
        {:ok, tenant}
    end
  end

  def get_tenant_for_origin(_), do: {:error, :invalid_origin}

  @doc """
  Returns true if the origin is in the whitelist.
  """
  @spec whitelisted?(String.t()) :: boolean()
  def whitelisted?(origin) when is_binary(origin) do
    case get_tenant_for_origin(origin) do
      {:ok, _tenant} -> true
      {:error, _reason} -> false
    end
  end

  def whitelisted?(_), do: false

  # Private methods

  @spec clean_origin(String.t()) :: String.t()
  defp clean_origin(origin) when is_binary(origin) do
    origin
    |> String.trim()
    |> String.downcase()
    |> String.replace_prefix("https://", "")
    |> String.replace_prefix("http://", "")
    |> String.replace_prefix("www.", "")
    |> String.trim("/")
    |> String.trim()
  end

  defp clean_origin(_), do: ""

end
