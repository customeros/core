defmodule Core.Integrations.Registry do
  @moduledoc """
  Registry for integration providers.

  This module maintains a registry of available integration providers and their
  implementations. It provides functions for:
  - Looking up provider implementations
  - Managing provider lifecycle
  - Listing and managing connections

  This is a simple module that doesn't maintain any state, so it doesn't need
  to be supervised.
  """

  alias Core.Integrations.Connections
  alias Core.Integrations.OAuth.Providers.HubSpot, as: HubSpotOAuth
  alias Core.Integrations.OAuth.Providers.GoogleAds, as: GoogleAdsOAuth
  alias Core.Integrations.Providers.HubSpot.{Client, Company, Webhook}
  alias Core.Integrations.Providers.GoogleAds.Client, as: GoogleAdsClient

  @doc """
  Gets a connection for a tenant and provider.

  ## Examples

      iex> get_connection("tenant_123", :hubspot)
      {:ok, %Connection{}}

      iex> get_connection("tenant_123", :nonexistent)
      {:error, :not_found}
  """
  def get_connection(tenant_id, provider) do
    Connections.get_connection(tenant_id, provider)
  end

  @doc """
  Gets the OAuth implementation for a provider.

  ## Examples

      iex> get_oauth(:hubspot)
      {:ok, HubSpotOAuth}

      iex> get_oauth(:nonexistent)
      {:error, :not_found}
  """
  def get_oauth(:hubspot), do: {:ok, HubSpotOAuth}
  def get_oauth(:google_ads), do: {:ok, GoogleAdsOAuth}
  def get_oauth(_), do: {:error, :not_found}

  @doc """
  Gets the client implementation for a provider.

  ## Examples

      iex> get_client(:hubspot)
      {:ok, Client}

      iex> get_client(:nonexistent)
      {:error, :not_found}
  """
  def get_client(:hubspot), do: {:ok, Client}
  def get_client(:google_ads), do: {:ok, GoogleAdsClient}
  def get_client(_), do: {:error, :not_found}

  @doc """
  Gets the company implementation for a provider.

  ## Examples

      iex> get_company(:hubspot)
      {:ok, Company}

      iex> get_company(:nonexistent)
      {:error, :not_found}
  """
  def get_company(:hubspot), do: {:ok, Company}
  def get_company(_), do: {:error, :not_found}

  @doc """
  Gets the webhook implementation for a provider.

  ## Examples

      iex> get_webhook(:hubspot)
      {:ok, Webhook}

      iex> get_webhook(:nonexistent)
      {:error, :not_found}
  """
  def get_webhook(:hubspot), do: {:ok, Webhook}
  def get_webhook(_), do: {:error, :not_found}

  @doc """
  Lists all available providers.

  ## Examples

      iex> list_providers()
      [:hubspot]
  """
  def list_providers do
    [:hubspot]
  end

  @doc """
  Checks if a provider is available.

  ## Examples

      iex> provider_available?(:hubspot)
      true

      iex> provider_available?(:nonexistent)
      false
  """
  def provider_available?(provider) do
    provider in list_providers()
  end

  @doc """
  Lists all connections for a tenant.

  ## Parameters
    - tenant_id - The ID of the tenant to list connections for

  ## Returns
    - `{:ok, [Connection.t()]}` - List of connections
    - `{:error, term()}` - Error reason

  ## Examples

      iex> list_connections("tenant_123")
      {:ok, [%Connection{provider: :hubspot, ...}]}

      iex> list_connections("nonexistent")
      {:error, :not_found}
  """
  def list_connections(tenant_id) do
    Connections.list_connections(tenant_id)
  end
end
