defmodule Core.Integrations.OAuth.Token do
  @moduledoc """
  Represents an OAuth token with its associated metadata.

  This module provides a struct and functions for working with OAuth tokens,
  including:
  - Token creation and validation
  - Expiration checking
  - Token refresh handling
  """

  @type t :: %__MODULE__{
          access_token: String.t(),
          refresh_token: String.t() | nil,
          token_type: String.t(),
          expires_at: DateTime.t() | nil
        }

  defstruct [
    :access_token,
    :refresh_token,
    :token_type,
    :expires_at
  ]

  @doc """
  Creates a new token struct from OAuth response data.

  ## Parameters
  - `data` - Map containing token data with string keys

  ## Returns
  - `{:ok, t()}` - The created token
  - `{:error, reason}` - Error reason

  ## Examples

      iex> Token.new(%{
      ...>   "access_token" => "access123",
      ...>   "refresh_token" => "refresh123",
      ...>   "token_type" => "Bearer",
      ...>   "expires_in" => 3600
      ...> })
      {:ok, %Token{
        access_token: "access123",
        refresh_token: "refresh123",
        token_type: "Bearer",
        expires_at: #DateTime<...>,
      }}

      iex> Token.new(%{"access_token" => "access123"})
      {:error, :invalid_token_data}
  """
  def new(%{"access_token" => access_token} = data) when is_binary(access_token) do
    with {:ok, expires_at} <- get_expires_at(data),
         {:ok, token_type} <- get_token_type(data),
         {:ok, refresh_token} <- get_refresh_token(data) do
      {:ok,
       %__MODULE__{
         access_token: access_token,
         refresh_token: refresh_token,
         token_type: token_type,
         expires_at: expires_at
       }}
    end
  end

  def new(_), do: {:error, :invalid_token_data}

  @doc """
  Checks if a token is expired.

  ## Parameters
  - `token` - The token to check

  ## Returns
  - `true` if the token is expired or has no expiration
  - `false` if the token is still valid

  ## Examples

      iex> token = %Token{expires_at: DateTime.utc_now()}
      iex> Token.expired?(token)
      false

      iex> token = %Token{expires_at: DateTime.add(DateTime.utc_now(), -3600)}
      iex> Token.expired?(token)
      true
  """
  def expired?(%__MODULE__{expires_at: nil}), do: true
  def expired?(%__MODULE__{expires_at: expires_at}), do: DateTime.compare(expires_at, DateTime.utc_now()) == :lt

  @doc """
  Checks if a token can be refreshed.

  ## Parameters
  - `token` - The token to check

  ## Returns
  - `true` if the token has a refresh token
  - `false` otherwise

  ## Examples

      iex> token = %Token{refresh_token: "refresh123"}
      iex> Token.refreshable?(token)
      true

      iex> token = %Token{refresh_token: nil}
      iex> Token.refreshable?(token)
      false
  """
  def refreshable?(%__MODULE__{refresh_token: refresh_token}) when is_binary(refresh_token), do: true
  def refreshable?(_), do: false

  # Private helper functions

  defp get_expires_at(%{"expires_in" => expires_in}) when is_integer(expires_in) do
    {:ok, DateTime.add(DateTime.utc_now(), expires_in)}
  end

  defp get_expires_at(_), do: {:ok, nil}

  defp get_token_type(%{"token_type" => type}) when is_binary(type), do: {:ok, type}
  defp get_token_type(_), do: {:ok, "Bearer"}

  defp get_refresh_token(%{"refresh_token" => token}) when is_binary(token), do: {:ok, token}
  defp get_refresh_token(_), do: {:ok, nil}
end
