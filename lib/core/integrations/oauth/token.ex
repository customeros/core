defmodule Core.Integrations.OAuth.Token do
  @moduledoc """
  Manages OAuth tokens for integration providers.

  This module handles the storage, retrieval, and management of OAuth tokens
  for different integration providers. It provides a secure way to store tokens
  and handles token refresh when they expire.

  ## Features

  - Secure token storage
  - Automatic token refresh
  - Token encryption at rest
  - Token lifecycle management
  """

  @type provider :: atom()
  @type token :: %{
          access_token: String.t(),
          refresh_token: String.t(),
          expires_at: DateTime.t(),
          token_type: String.t()
        }

  @doc """
  Stores a new token for a provider.
  """
  @callback store_token(provider(), token()) :: :ok | {:error, term()}

  @doc """
  Retrieves a token for a provider.
  """
  @callback get_token(provider()) :: {:ok, token()} | {:error, term()}

  @doc """
  Deletes a token for a provider.
  """
  @callback delete_token(provider()) :: :ok | {:error, term()}

  @doc """
  Checks if a token is expired.
  """
  @callback token_expired?(token()) :: boolean()
end
