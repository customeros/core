defmodule Core.Auth.ApiTokens.ApiToken do
  use Ecto.Schema
  import Ecto.Query
  alias Core.Auth.ApiTokens.ApiToken
  alias Core.Auth.Users.User

  @hash_algorithm :sha256
  @rand_size 32

  # API tokens should have longer validity periods than session tokens
  # since they're used for programmatic access
  @api_token_validity_in_days 365
  @api_token_prefix "cos_"

  @primary_key {:id, :string, autogenerate: false}
  schema "api_tokens" do
    field(:token, :binary)
    field(:name, :string)
    field(:last_used_at, :utc_datetime)
    field(:expires_at, :utc_datetime)
    field(:user_id, :string)
    field(:scopes, {:array, :string}, default: [])
    field(:active, :boolean, default: true)

    timestamps(updated_at: false)
  end

  @doc """
  Generates an API token for Bearer authentication.

  The token is hashed before storage for security. The raw token
  is returned to be given to the user, while the hashed version
  is stored in the database.

  API tokens are designed for long-term programmatic access and
  include additional metadata like name, scopes, and expiration.
  """
  def build_api_token(user, name, opts \\ []) do
    scopes = Keyword.get(opts, :scopes, ["read"])

    expires_in_days =
      Keyword.get(opts, :expires_in_days, @api_token_validity_in_days)

    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    # Create a user-friendly token with prefix
    encoded_token =
      @api_token_prefix <> Base.url_encode64(token, padding: false)

    expires_at =
      DateTime.utc_now()
      |> DateTime.add(expires_in_days * 24 * 60 * 60, :second)
      |> DateTime.truncate(:second)

    {encoded_token,
     %ApiToken{
       id: Core.Utils.IdGenerator.generate_id_21("api_token"),
       token: hashed_token,
       name: name,
       user_id: user.id,
       scopes: scopes,
       expires_at: expires_at,
       active: true
     }}
  end

  @doc """
  Verifies an API token and returns the associated user.

  The token is valid if:
  - It matches the hashed value in the database
  - It has not expired
  - It is marked as active
  - The associated user exists
  """
  def verify_api_token_query(token) do
    case extract_token_from_bearer(token) do
      {:ok, raw_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, raw_token)

        query =
          from token in ApiToken,
            join: user in User,
            on: token.user_id == user.id,
            where:
              token.token == ^hashed_token and
                token.active == true and
                (is_nil(token.expires_at) or
                   token.expires_at > ^DateTime.utc_now()),
            select: {user, token}

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Extracts the raw token from a Bearer token string or prefixed token.
  Handles both "Bearer cos_..." and "cos_..." formats.
  """
  def extract_token_from_bearer(token_string) when is_binary(token_string) do
    token_string
    |> String.trim()
    |> case do
      "Bearer " <> token -> extract_raw_token(token)
      token -> extract_raw_token(token)
    end
  end

  def extract_token_from_bearer(_), do: :error

  defp extract_raw_token(@api_token_prefix <> encoded_token) do
    case Base.url_decode64(encoded_token, padding: false) do
      {:ok, raw_token} -> {:ok, raw_token}
      :error -> :error
    end
  end

  defp extract_raw_token(_), do: :error

  @doc """
  Updates the last_used_at timestamp for an API token.
  This is useful for tracking token usage.
  """
  def touch_token(%ApiToken{} = api_token) do
    api_token
    |> Ecto.Changeset.change(%{
      last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Core.Repo.update()
  end

  @doc """
  Deactivates an API token without deleting it.
  This allows for audit trails while preventing further use.
  """
  def deactivate_token(%ApiToken{} = api_token) do
    api_token
    |> Ecto.Changeset.change(%{active: false})
    |> Core.Repo.update()
  end

  @doc """
  Gets all API tokens for a user, optionally filtering by active status.
  """
  def by_user_query(user, opts \\ []) do
    active_only = Keyword.get(opts, :active_only, false)

    query = from t in ApiToken, where: t.user_id == ^user.id

    if active_only do
      from t in query,
        where:
          t.active == true and
            (is_nil(t.expires_at) or t.expires_at > ^DateTime.utc_now())
    else
      query
    end
  end

  @doc """
  Gets an API token by its ID for a specific user.
  """
  def by_user_and_id_query(user, token_id) do
    from t in ApiToken,
      where: t.user_id == ^user.id and t.id == ^token_id
  end

  @doc """
  Checks if a token has a specific scope.
  """
  def has_scope?(%ApiToken{scopes: scopes}, required_scope) do
    required_scope in scopes or "admin" in scopes
  end

  @doc """
  Returns all available scopes for API tokens.
  """
  def available_scopes do
    ["read", "write", "admin"]
  end
end
