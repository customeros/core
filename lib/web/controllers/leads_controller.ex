defmodule Web.LeadsController do
    use Web, :controller
  
    def index(conn, _params) do
      svg_content = File.read!("priv/static/icons.svg")

      conn
      |> render_inertia("Leads")
    end
  end
  