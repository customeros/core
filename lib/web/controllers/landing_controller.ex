defmodule Web.LandingController do
  use Web, :controller

  def index(conn, _params) do
    conn
    |> assign_prop(:companies, [])
    |> render_inertia("Leads")
  end

  def redirect(conn, _params) do
    if conn.assigns[:current_user] do
      Phoenix.Controller.redirect(conn, to: ~p"/leads")
    else
      Phoenix.Controller.redirect(conn, to: ~p"/signin", flash: %{})
    end
  end
end
