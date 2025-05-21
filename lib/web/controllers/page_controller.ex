defmodule Web.PageController do
    use Web, :controller
  
    def home(conn, _params) do
      conn
      |> assign(:flash, %{})
    #   |> assign_prop(:place, "CustomerOs")
    #   |> assign_prop(:facts, [
    #     %{key: "Population", value: "8 billion"},
    #     %{key: "Countries", value: "195"},
    #     %{key: "Languages", value: "7,000+"}
    #   ])
    #   |> render_inertia("DemoPageOne", layout: {Web.Layouts, :app})
    render(conn, :home, layout: {Web.Layouts, :app})
    end
  end
  