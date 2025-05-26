defmodule Core.Auth.ApiTokensTest do
  use Core.DataCase, async: true

  alias Core.Auth.{ApiTokens, Users}
  alias Core.Auth.ApiTokens.ApiToken

  describe "create_api_token/3" do
    test "creates a valid API token for a user" do
      user = user_fixture()

      assert {:ok, token_string, %ApiToken{} = api_token} =
               ApiTokens.create_api_token(user, "Test Token")

      assert String.starts_with?(token_string, "cos_")
      assert api_token.name == "Test Token"
      assert api_token.user_id == user.id
      assert api_token.scopes == ["read"]
      assert api_token.active == true
      assert api_token.expires_at != nil
    end

    test "creates API token with custom scopes" do
      user = user_fixture()

      assert {:ok, _token_string, %ApiToken{} = api_token} =
               ApiTokens.create_api_token(user, "Admin Token",
                 scopes: ["admin"]
               )

      assert api_token.scopes == ["admin"]
    end

    test "creates API token with custom expiration" do
      user = user_fixture()

      assert {:ok, _token_string, %ApiToken{} = api_token} =
               ApiTokens.create_api_token(user, "Short Token",
                 expires_in_days: 30
               )

      # Check that expiration is roughly 30 days from now
      expected_expiry =
        DateTime.add(DateTime.utc_now(), 30 * 24 * 60 * 60, :second)

      diff = DateTime.diff(api_token.expires_at, expected_expiry, :second)
      # Within 1 minute tolerance
      assert abs(diff) < 60
    end
  end

  describe "verify_api_token/1" do
    test "verifies a valid Bearer token" do
      user = user_fixture()

      {:ok, token_string, _api_token} =
        ApiTokens.create_api_token(user, "Test Token")

      bearer_token = "Bearer #{token_string}"

      assert {:ok, verified_user, verified_token} =
               ApiTokens.verify_api_token(bearer_token)

      assert verified_user.id == user.id
      assert verified_token.name == "Test Token"
    end

    test "verifies a valid token without Bearer prefix" do
      user = user_fixture()

      {:ok, token_string, _api_token} =
        ApiTokens.create_api_token(user, "Test Token")

      assert {:ok, verified_user, _verified_token} =
               ApiTokens.verify_api_token(token_string)

      assert verified_user.id == user.id
    end

    test "rejects invalid token" do
      assert {:error, :invalid_token} =
               ApiTokens.verify_api_token("Bearer invalid_token")

      assert {:error, :invalid_token} =
               ApiTokens.verify_api_token("invalid_token")
    end

    test "rejects deactivated token" do
      user = user_fixture()

      {:ok, token_string, api_token} =
        ApiTokens.create_api_token(user, "Test Token")

      # Deactivate the token
      {:ok, _} = ApiTokens.deactivate_api_token(api_token)

      assert {:error, :invalid_token} = ApiTokens.verify_api_token(token_string)
    end
  end

  describe "list_user_api_tokens/2" do
    test "lists all tokens for a user" do
      user = user_fixture()
      {:ok, _token1, _} = ApiTokens.create_api_token(user, "Token 1")
      {:ok, _token2, _} = ApiTokens.create_api_token(user, "Token 2")

      tokens = ApiTokens.list_user_api_tokens(user)
      assert length(tokens) == 2

      token_names = Enum.map(tokens, & &1.name)
      assert "Token 1" in token_names
      assert "Token 2" in token_names
    end

    test "filters active tokens only" do
      user = user_fixture()
      {:ok, _token1, _} = ApiTokens.create_api_token(user, "Active Token")

      {:ok, _token2, inactive_token} =
        ApiTokens.create_api_token(user, "Inactive Token")

      # Deactivate one token
      {:ok, _} = ApiTokens.deactivate_api_token(inactive_token)

      all_tokens = ApiTokens.list_user_api_tokens(user)
      active_tokens = ApiTokens.list_user_api_tokens(user, active_only: true)

      assert length(all_tokens) == 2
      assert length(active_tokens) == 1
      assert hd(active_tokens).name == "Active Token"
    end
  end

  describe "token_has_scope?/2" do
    test "checks token scopes correctly" do
      user = user_fixture()

      {:ok, _token_string, read_token} =
        ApiTokens.create_api_token(user, "Read Token", scopes: ["read"])

      {:ok, _token_string, admin_token} =
        ApiTokens.create_api_token(user, "Admin Token", scopes: ["admin"])

      assert ApiTokens.token_has_scope?(read_token, "read")
      refute ApiTokens.token_has_scope?(read_token, "write")
      refute ApiTokens.token_has_scope?(read_token, "admin")

      # Admin tokens should have access to everything
      assert ApiTokens.token_has_scope?(admin_token, "read")
      assert ApiTokens.token_has_scope?(admin_token, "write")
      assert ApiTokens.token_has_scope?(admin_token, "admin")
    end
  end

  # Helper function to create a test user
  defp user_fixture(attrs \\ %{}) do
    email = "user#{System.unique_integer()}@example.com"

    {:ok, user} =
      attrs
      |> Enum.into(%{email: email})
      |> Users.register_user()

    user
  end
end
