defmodule Core.WebTracker.OriginTenantMapper do
  @moduledoc """
  Manages the mapping between whitelisted origins and their corresponding tenants.
  """
  alias Core.Auth.Tenants

  @err_invalid_origin {:error, "invalid origin"}
  @err_origin_blocked {:error, "origin blocked"}
  @err_origin_not_provided {:error, "origin not provided"}
  @err_origin_not_configured {:error, :origin_not_configured}

  @doc """
  Checks if given origin is whitelisted and returns its associated tenant.
  The origin can be provided with or without http:// or https:// prefix.
  If exact match is not found, checks if the origin is a subdomain of a whitelisted root domain.
  """
  def get_tenant_for_origin(origin)
      when is_binary(origin) and byte_size(origin) > 0 do
    cleaned_origin = clean_origin(origin)

    case find_tenant_for_domain(cleaned_origin) do
      {:ok, tenant} -> {:ok, tenant}
      @err_origin_not_configured -> check_subdomain_tenant(cleaned_origin)
    end
  end

  def get_tenant_for_origin(""), do: @err_origin_not_provided
  def get_tenant_for_origin(nil), do: @err_origin_not_provided
  def get_tenant_for_origin(_), do: @err_invalid_origin

  defp find_tenant_for_domain(domain) do
    case Tenants.get_tenant_by_domain(domain) do
      nil -> @err_origin_not_configured
      {:error, "tenant not found"} -> @err_origin_not_configured
      tenant -> {:ok, tenant}
    end
  end

  defp check_subdomain_tenant(domain) do
    case Core.Utils.DomainValidator.parse_root_and_subdomain(domain) do
      {:ok, %{subdomain: "careers"}} ->
        @err_origin_blocked

      {:ok, %{subdomain: "jobs"}} ->
        @err_origin_blocked

      {:ok, %{domain: domain, tld: tld}} ->
        root_domain = "#{domain}.#{tld}"
        find_tenant_for_domain(root_domain)

      {:error, _} ->
        @err_origin_not_configured
    end
  end

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
    |> then(fn cleaned ->
      cleaned
      |> String.split("/", parts: 2)
      |> List.first()
    end)
  end
end
