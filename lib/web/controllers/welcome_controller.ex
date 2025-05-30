defmodule Web.WelcomeController do
  use Web, :controller

  def index(conn, _params) do
    conn
    |> render_inertia("Welcome")
  end
end
