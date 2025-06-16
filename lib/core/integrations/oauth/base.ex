defmodule Core.Integrations.OAuth.Base do
  @moduledoc """
  Base behaviour for OAuth providers.

  This module defines the behaviour that all OAuth provider implementations
  must follow. It includes functions for:
  - Authorization URL generation
  - Token exchange
  - Token refresh
  - Token validation
  """

  @doc """
  Generates the authorization URL for the OAuth flow.

  ## Parameters
  - `tenant_id` - The tenant ID
  - `redirect_uri` - The URI to redirect to after authorization

  ## Returns
  - `String.t()` - The authorization URL
  """
  @callback authorize_url(tenant_id :: String.t(), redirect_uri :: String.t()) ::
              String.t()

  @doc """
  Exchanges an authorization code for an access token.

  ## Parameters
  - `code` - The authorization code
  - `redirect_uri` - The redirect URI used in the authorization request

  ## Returns
  - `{:ok, Core.Integrations.OAuth.Token.t()}` - The access token
  - `{:error, reason}` - Error reason
  """
  @callback exchange_code(code :: String.t(), redirect_uri :: String.t()) ::
              {:ok, Core.Integrations.OAuth.Token.t()} | {:error, term()}

  @doc """
  Refreshes an access token using a refresh token.

  ## Parameters
  - `connection` - The integration connection

  ## Returns
  - `{:ok, Core.Integrations.Connection.t()}` - The updated connection
  - `{:error, reason}` - Error reason
  """
  @callback refresh_token(connection :: Core.Integrations.Connection.t()) ::
              {:ok, Core.Integrations.Connection.t()} | {:error, term()}

  @doc """
  Validates an access token.

  ## Parameters
  - `connection` - The integration connection

  ## Returns
  - `{:ok, Core.Integrations.Connection.t()}` - The validated connection
  - `{:error, reason}` - Error reason
  """
  @callback validate_token(connection :: Core.Integrations.Connection.t()) ::
              {:ok, Core.Integrations.Connection.t()} | {:error, term()}
end
