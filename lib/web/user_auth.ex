defmodule Web.UserAuth do
  @moduledoc """
  Handles user authentication and session management for the web application.

  This module provides functions for:
  * User login and signup
  * Session management and token handling
  * Remember me functionality
  * LiveView authentication
  * User logout and session cleanup

  It integrates with the core authentication system and provides
  both traditional web session management and LiveView-specific
  authentication hooks.
  """

  use Web, :verified_routes

  import Plug.Conn
  import Phoenix.Controller
  import Inertia.Controller

  alias Core.Auth.Users
  alias Core.Auth.ApiTokens
  alias Core.Auth.Tenants
  alias Core.Stats

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_cos_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def login_user(conn, user, params \\ %{}) do
    token = Users.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> tap(fn _ -> Stats.register_event_start(user.id, :login) end)
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  def signup_user(conn, user, params \\ %{}) do
    token = Users.generate_user_session_token(user)

    conn
    |> renew_session()
    |> tap(fn _ -> Stats.register_event_start(user.id, :login) end)
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: signed_up_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Users.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      Web.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)

    user =
      user_token &&
        case Users.get_user_by_session_token(user_token) do
          nil -> nil
          user -> user
        end

    assign(conn, :current_user, user)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule ExampleWeb.PageLive do
        use ExampleWeb, :live_view

        on_mount {ExampleWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{ExampleWeb.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :error,
          "You must log in to access this page."
        )
        |> Phoenix.LiveView.redirect(to: ~p"/signin")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_token = session["user_token"] do
        Users.get_user_by_session_token(user_token)
      end
    end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      current_user = conn.assigns[:current_user]

      tenant =
        case Tenants.get_tenant_by_id(current_user.tenant_id) do
          {:ok, tenant} ->
            tenant
            |> Map.put(
              :workspace_icon_key,
              Core.Utils.Media.Images.get_cdn_url(tenant.workspace_icon_key)
            )

          _ ->
            nil
        end

      conn
      |> assign_prop(:current_user, current_user)
      |> assign_prop(:tenant, tenant)
    else
      if get_req_header(conn, "accept") == ["application/json"] do
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
        |> halt()
      else
        conn
        |> maybe_put_flash_error(conn.request_path)
        |> maybe_store_return_to()
        |> redirect(to: ~p"/signin")
        |> halt()
      end
    end
  end

  @doc """
  API-oriented authentication that assumes session-based auth from same origin.
  Returns JSON responses and doesn't use flash messages.
  """
  def require_authenticated_api_user(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()

      user ->
        conn
        |> assign(:current_user, user)
    end
  end

  defp maybe_put_flash_error(conn, "/") do
    conn
  end

  defp maybe_put_flash_error(conn, _path) do
    put_flash(conn, :error, "You must log in to access this page.")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  @doc """
  Authenticates API requests using Bearer tokens.

  Looks for Authorization header with Bearer token and validates it.
  If valid, assigns the current_user and api_token to the connection.
  """
  def authenticate_bearer_token(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> _token = auth_header] ->
        case ApiTokens.verify_api_token(auth_header) do
          {:ok, user, api_token} ->
            conn
            |> assign(:current_user, user)
            |> assign(:api_token, api_token)
            |> assign(:auth_method, :bearer_token)

          {:error, :invalid_token} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Invalid or expired API token"})
            |> halt()
        end

      [token] when is_binary(token) ->
        # Handle tokens without "Bearer " prefix
        case ApiTokens.verify_api_token(token) do
          {:ok, user, api_token} ->
            conn
            |> assign(:current_user, user)
            |> assign(:api_token, api_token)
            |> assign(:auth_method, :bearer_token)

          {:error, :invalid_token} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Invalid or expired API token"})
            |> halt()
        end

      [] ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Missing Authorization header"})
        |> halt()

      _other ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid Authorization header format"})
        |> halt()
    end
  end

  @doc """
  Requires that the API token has a specific scope.

  Should be used after authenticate_bearer_token/2.
  """
  def require_api_scope(conn, scope) when is_binary(scope) do
    case conn.assigns[:api_token] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "API token required"})
        |> halt()

      api_token ->
        if ApiTokens.token_has_scope?(api_token, scope) do
          conn
        else
          conn
          |> put_status(:forbidden)
          |> json(%{
            error: "Insufficient permissions. Required scope: #{scope}"
          })
          |> halt()
        end
    end
  end

  def require_api_scope(conn, opts) do
    scope = Keyword.fetch!(opts, :scope)
    require_api_scope(conn, scope)
  end

  @doc """
  Flexible authentication that supports both session and Bearer token auth.

  Tries Bearer token first, then falls back to session authentication.
  Useful for endpoints that need to support both web and API access.
  """
  def authenticate_user_flexible(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> _token] ->
        authenticate_bearer_token(conn, [])

      [token] when is_binary(token) ->
        authenticate_bearer_token(conn, [])

      [] ->
        # Fall back to session authentication
        conn = fetch_current_user(conn, [])

        case conn.assigns[:current_user] do
          nil ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Authentication required"})
            |> halt()

          user ->
            conn
            |> assign(:current_user, user)
            |> assign(:auth_method, :session)
        end

      _other ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid Authorization header format"})
        |> halt()
    end
  end

  defp signed_in_path(_conn), do: ~p"/leads"
  defp signed_up_path(_conn), do: ~p"/welcome"

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(
      :live_socket_id,
      "users_sessions:#{Base.url_encode64(token)}"
    )
  end
end
