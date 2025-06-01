defmodule Web.ApiTokenController do
  use Web, :controller

  alias Core.Auth.ApiTokens
  alias Core.Auth.ApiTokens.ApiToken
  alias Ecto.Changeset

  @doc """
  Lists all API tokens for the current user.
  """
  def index(conn, _params) do
    user = conn.assigns.current_user
    tokens = ApiTokens.list_user_api_tokens(user)

    # Don't expose the actual token values, only metadata
    safe_tokens =
      Enum.map(tokens, fn token ->
        %{
          id: token.id,
          name: token.name,
          scopes: token.scopes,
          active: token.active,
          last_used_at: token.last_used_at,
          expires_at: token.expires_at,
          inserted_at: token.inserted_at
        }
      end)

    json(conn, %{tokens: safe_tokens})
  end

  @doc """
  Creates a new API token for the current user.
  """
  def create(conn, %{"name" => name} = params) do
    user = conn.assigns.current_user
    scopes = Map.get(params, "scopes", ["read"])
    expires_in_days = Map.get(params, "expires_in_days", 365)

    # Validate scopes
    available_scopes = ApiTokens.available_scopes()
    invalid_scopes = scopes -- available_scopes

    if invalid_scopes != [] do
      conn
      |> put_status(:bad_request)
      |> json(%{
        error: "Invalid scopes",
        invalid_scopes: invalid_scopes,
        available_scopes: available_scopes
      })
    else
      case ApiTokens.create_api_token(user, name,
             scopes: scopes,
             expires_in_days: expires_in_days
           ) do
        {:ok, token_string, api_token} ->
          conn
          |> put_status(:created)
          |> json(%{
            message: "API token created successfully",
            token: token_string,
            token_info: %{
              id: api_token.id,
              name: api_token.name,
              scopes: api_token.scopes,
              expires_at: api_token.expires_at
            },
            warning:
              "Store this token securely. You won't be able to see it again."
          })

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            error: "Failed to create token",
            details: errors_from_changeset(changeset)
          })
      end
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required field: name"})
  end

  @doc """
  Deactivates an API token.
  """
  def delete(conn, %{"id" => token_id}) do
    user = conn.assigns.current_user

    case ApiTokens.deactivate_user_api_token(user, token_id) do
      {:ok, _api_token} ->
        json(conn, %{message: "API token deactivated successfully"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "API token not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Failed to deactivate token",
          details: errors_from_changeset(changeset)
        })
    end
  end

  @doc """
  Shows details of a specific API token.
  """
  def show(conn, %{"id" => token_id}) do
    user = conn.assigns.current_user

    case ApiTokens.get_user_api_token(user, token_id) do
      %ApiToken{} = token ->
        safe_token = %{
          id: token.id,
          name: token.name,
          scopes: token.scopes,
          active: token.active,
          last_used_at: token.last_used_at,
          expires_at: token.expires_at,
          inserted_at: token.inserted_at
        }

        json(conn, %{token: safe_token})

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "API token not found"})
    end
  end

  @doc """
  Updates an API token (currently only supports updating the name).
  """
  def update(conn, %{"id" => token_id, "name" => new_name}) do
    user = conn.assigns.current_user

    case ApiTokens.get_user_api_token(user, token_id) do
      %ApiToken{} = token ->
        changeset = Changeset.change(token, %{name: new_name})

        case Core.Repo.update(changeset) do
          {:ok, updated_token} ->
            safe_token = %{
              id: updated_token.id,
              name: updated_token.name,
              scopes: updated_token.scopes,
              active: updated_token.active,
              last_used_at: updated_token.last_used_at,
              expires_at: updated_token.expires_at,
              inserted_at: updated_token.inserted_at
            }

            json(conn, %{token: safe_token})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to update token",
              details: errors_from_changeset(changeset)
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "API token not found"})
    end
  end

  def update(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required field: name"})
  end

  # Helper function to extract errors from changeset
  defp errors_from_changeset(changeset) do
    Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
