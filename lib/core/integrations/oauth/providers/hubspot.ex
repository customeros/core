defmodule Core.Integrations.OAuth.Providers.HubSpot do
  @moduledoc """
  HubSpot OAuth provider implementation.

  This module handles the OAuth flow for HubSpot integration, including:
  - Authorization URL generation
  - Token exchange
  - Token refresh
  - Token validation
  """

  alias Core.Integrations.OAuth.Base
  alias Core.Integrations.OAuth.Token
  alias Core.Integrations.Connection
  alias Core.Integrations.Connections

  @behaviour Base

  @impl Base
  def authorize_url(tenant_id, redirect_uri) do
    params = %{
      client_id: client_id(),
      redirect_uri: redirect_uri,
      scope: scopes(),
      state: generate_state(tenant_id)
    }

    "https://app.hubspot.com/oauth/authorize?#{URI.encode_query(params)}"
  end

  @impl Base
  def exchange_code(code, redirect_uri) do
    params = %{
      grant_type: "authorization_code",
      client_id: client_id(),
      client_secret: client_secret(),
      redirect_uri: redirect_uri,
      code: code
    }

    case post_token(params) do
      {:ok, token_data} -> {:ok, Token.new(token_data)}
      error -> error
    end
  end

  @impl Base
  def refresh_token(%Connection{} = connection) do
    params = %{
      grant_type: "refresh_token",
      client_id: client_id(),
      client_secret: client_secret(),
      refresh_token: connection.refresh_token
    }

    case post_token(params) do
      {:ok, token_data} ->
        token = Token.new(token_data)
        Connections.update_connection(connection, %{
          access_token: token.access_token,
          refresh_token: token.refresh_token,
          expires_at: token.expires_at,
          scopes: token.scopes,
          status: :active
        })

      {:error, reason} ->
        Connections.update_connection(connection, %{
          status: :error,
          last_sync_error: "Token refresh failed: #{inspect(reason)}"
        })
    end
  end

  @impl Base
  def validate_token(%Connection{} = connection) do
    case get(connection) do
      {:ok, %{"user" => _user}} -> {:ok, connection}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get(connection) do
    headers = [{"authorization", "Bearer #{connection.access_token}"}]

    case HTTPoison.get("https://api.hubapi.com/oauth/v1/access-tokens/#{connection.access_token}", headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status, body: body}} ->
        {:error, "HTTP #{status}: #{body}"}

      {:error, %{reason: reason}} ->
        {:error, reason}
    end
  end

  # Private functions

  defp client_id, do: Application.get_env(:core, :hubspot_client_id)
  defp client_secret, do: Application.get_env(:core, :hubspot_client_secret)

  defp scopes do
    [
      "crm.objects.contacts.read",
      "crm.objects.contacts.write",
      "crm.objects.companies.read",
      "crm.objects.companies.write"
    ]
    |> Enum.join(" ")
  end

  defp generate_state(tenant_id) do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16()
    |> Kernel.<>("_#{tenant_id}")
  end

  defp post_token(params) do
    headers = [{"content-type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://api.hubapi.com/oauth/v1/token", URI.encode_query(params), headers) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status_code: status, body: body}} ->
        {:error, "HTTP #{status}: #{body}"}

      {:error, %{reason: reason}} ->
        {:error, reason}
    end
  end
end
