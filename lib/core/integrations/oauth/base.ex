defmodule Core.Integrations.OAuth.Base do
  @moduledoc """
  Base behaviour module for OAuth integration providers.

  This module defines the contract that all OAuth providers must implement.
  It provides a standardized way to handle OAuth authentication across different
  integration providers (HubSpot, Salesforce, etc.).

  ## Usage

  ```elixir
  defmodule Core.Integrations.HubSpot.OAuth do
    @behaviour Core.Integrations.OAuth.Base

    # Implement required callbacks
  end
  ```

  ## Required Callbacks

  - `authorize_url/1` - Generate the OAuth authorization URL
  - `get_token/2` - Exchange authorization code for access token
  - `refresh_token/1` - Refresh expired access token
  - `revoke_token/1` - Revoke access token
  """

  @type provider :: atom()
  @type token :: %{
          access_token: String.t(),
          refresh_token: String.t(),
          expires_at: DateTime.t(),
          token_type: String.t()
        }

  @callback authorize_url(provider()) :: {:ok, String.t()} | {:error, term()}
  @callback get_token(provider(), String.t()) :: {:ok, token()} | {:error, term()}
  @callback refresh_token(provider()) :: {:ok, token()} | {:error, term()}
  @callback revoke_token(provider()) :: :ok | {:error, term()}
end
