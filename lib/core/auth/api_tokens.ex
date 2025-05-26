defmodule Core.Auth.ApiTokens do
  @moduledoc """
  The ApiTokens context for managing API tokens.

  This module provides functions for creating, verifying, and managing
  API tokens used for Bearer authentication in API requests.
  """

  import Ecto.Query, warn: false
  alias Core.Repo
  alias Core.Auth.ApiTokens.ApiToken
  alias Core.Auth.Users.User

  @doc """
  Creates a new API token for a user.

  ## Examples

      iex> create_api_token(user, "My API Token")
      {:ok, "cos_abc123...", %ApiToken{}}

      iex> create_api_token(user, "Admin Token", scopes: ["admin"])
      {:ok, "cos_xyz789...", %ApiToken{}}
  """
  def create_api_token(%User{} = user, name, opts \\ []) do
    {token_string, api_token} = ApiToken.build_api_token(user, name, opts)

    case Repo.insert(api_token) do
      {:ok, saved_token} -> {:ok, token_string, saved_token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Verifies an API token and returns the associated user and token.

  ## Examples

      iex> verify_api_token("Bearer cos_abc123...")
      {:ok, %User{}, %ApiToken{}}

      iex> verify_api_token("cos_abc123...")
      {:ok, %User{}, %ApiToken{}}

      iex> verify_api_token("invalid_token")
      {:error, :invalid_token}
  """
  def verify_api_token(token_string) do
    case ApiToken.verify_api_token_query(token_string) do
      {:ok, query} ->
        case Repo.one(query) do
          {user, api_token} ->
            # Update last_used_at timestamp asynchronously
            Task.start(fn -> ApiToken.touch_token(api_token) end)
            {:ok, user, api_token}

          nil ->
            {:error, :invalid_token}
        end

      :error ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Gets all API tokens for a user.

  ## Options

    * `:active_only` - If true, only returns active and non-expired tokens (default: false)
  """
  def list_user_api_tokens(%User{} = user, opts \\ []) do
    user
    |> ApiToken.by_user_query(opts)
    |> Repo.all()
  end

  @doc """
  Gets a specific API token by ID for a user.
  """
  def get_user_api_token(%User{} = user, token_id) do
    user
    |> ApiToken.by_user_and_id_query(token_id)
    |> Repo.one()
  end

  @doc """
  Deactivates an API token.

  This marks the token as inactive without deleting it,
  preserving audit trails.
  """
  def deactivate_api_token(%ApiToken{} = api_token) do
    ApiToken.deactivate_token(api_token)
  end

  @doc """
  Deactivates an API token by ID for a specific user.
  """
  def deactivate_user_api_token(%User{} = user, token_id) do
    case get_user_api_token(user, token_id) do
      %ApiToken{} = api_token ->
        deactivate_api_token(api_token)

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Deletes an API token permanently.

  Use with caution - this removes all traces of the token.
  Consider using `deactivate_api_token/1` instead for audit trails.
  """
  def delete_api_token(%ApiToken{} = api_token) do
    Repo.delete(api_token)
  end

  @doc """
  Deletes an API token by ID for a specific user.
  """
  def delete_user_api_token(%User{} = user, token_id) do
    case get_user_api_token(user, token_id) do
      %ApiToken{} = api_token ->
        delete_api_token(api_token)

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Checks if an API token has a specific scope.
  """
  def token_has_scope?(%ApiToken{} = api_token, scope) do
    ApiToken.has_scope?(api_token, scope)
  end

  @doc """
  Returns all available scopes for API tokens.
  """
  def available_scopes do
    ApiToken.available_scopes()
  end

  @doc """
  Deactivates all API tokens for a user.

  Useful when a user's account is compromised or when they
  want to revoke all existing API access.
  """
  def deactivate_all_user_tokens(%User{} = user) do
    from(t in ApiToken, where: t.user_id == ^user.id and t.active == true)
    |> Repo.update_all(set: [active: false])
  end

  @doc """
  Cleans up expired tokens.

  This function can be called periodically to remove tokens
  that have passed their expiration date.
  """
  def cleanup_expired_tokens do
    now = DateTime.utc_now()

    from(t in ApiToken,
      where: not is_nil(t.expires_at) and t.expires_at < ^now
    )
    |> Repo.delete_all()
  end
end
