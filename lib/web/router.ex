defmodule Web.Router do
  use Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Inertia.Plug
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug Web.Plugs.ValidateHeaders
  end

  pipeline :public_api do
    plug :accepts, ["json"]
  end

  pipeline :graphql do
    plug Web.Plugs.ValidateHeaders
  end

  # Health check endpoint
  scope "/", Web do
    pipe_through :public_api

    get "/health", HealthController, :index
  end

  # Browser routes
  scope "/", Web do
    pipe_through :browser

    get "/test", PageController, :home
  end

  scope "/graphql" do
    pipe_through :graphql
    forward "/", Absinthe.Plug, schema: Web.Graphql.Schema
  end

  forward "/graphiql",
          Absinthe.Plug.GraphiQL,
          schema: Web.Graphql.Schema,
          interface: :simple

  # V1 API endpoints
  scope "/v1", Web do
    pipe_through :public_api

    post "/events", WebTrackerController, :create
  end

  # Protected API routes (auth required)
  scope "/api", Web do
    pipe_through :api

    resources "/documents", DocumentController, only: [:create]
    post "/organizations/:organization_id/documents", DocumentController, :create
    get "/organizations/:organization_id/documents", DocumentController, :index
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:realtime, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: Web.Telemetry
      # forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
