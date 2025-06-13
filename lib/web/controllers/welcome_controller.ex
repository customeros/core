defmodule Web.WelcomeController do
  use Web, :controller

  def index(conn, _params) do
    conn
    |> assign_prop(:page_title, "Welcome | CustomerOS")
    |> render_inertia("Welcome")
  end
end
