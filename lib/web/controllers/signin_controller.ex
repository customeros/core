defmodule Web.AuthController do
  use Web, :controller
  alias Core.Auth.Users
  alias Core.Auth.Users.User

  def index(conn, _params) do
    conn |> render_inertia("Signin")
  end

  def send_magic_link(conn, %{"email" => email}) do
    case Users.login_or_register_user(email) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: ~p"/signin")

      {:error, errors} ->
        conn
        |> assign_prop(:errors, %{
          email: Keyword.get(errors, :email, "Something went wrong")
        })
        |> render_inertia("Signin")
    end
  end

  def signin_with_token(conn, %{"token" => token} = _params) do
    case Users.get_user_by_email_token(token, "magic_link") do
      %User{} = user ->
        {:ok, user} = Users.confirm_user(user)

        conn
        |> put_flash(:info, "Logged in successfully.")
        |> Web.UserAuth.login_user(user)

      _ ->
        conn
        |> put_flash(:error, "That link didn't seem to work. Please try again.")
        |> redirect(to: ~p"/signin")
    end
  end

  def signup_with_token(conn, %{"token" => token} = _params) do
    case Users.get_user_by_email_token(token, "magic_link") do
      %User{} = user ->
        {:ok, user} = Users.confirm_user(user)

        conn
        |> put_flash(:info, "Logged in successfully.")
        |> Web.UserAuth.signup_user(user)

      _ ->
        conn
        |> put_flash(:error, "That link didn't seem to work. Please try again.")
        |> redirect(to: ~p"/signin")
    end
  end
end
