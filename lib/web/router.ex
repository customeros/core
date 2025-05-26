defmodule Web.Router do
  use Web, :router

  import Web.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Web.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug Inertia.Plug
  end

  pipeline :redirect_if_authenticated do
    plug :redirect_if_user_is_authenticated
  end

  pipeline :require_authenticated do
    plug :require_authenticated_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_current_user
    plug :require_authenticated_api_user
  end

  pipeline :public_api do
    plug :accepts, ["json"]
  end

  pipeline :bearer_api do
    plug :accepts, ["json"]
    plug :authenticate_bearer_token
  end

  pipeline :bearer_api_read do
    plug :accepts, ["json"]
    plug :authenticate_bearer_token
    plug :require_api_scope, scope: "read"
  end

  pipeline :bearer_api_write do
    plug :accepts, ["json"]
    plug :authenticate_bearer_token
    plug :require_api_scope, scope: "write"
  end

  pipeline :bearer_api_admin do
    plug :accepts, ["json"]
    plug :authenticate_bearer_token
    plug :require_api_scope, scope: "admin"
  end

  pipeline :flexible_api do
    plug :accepts, ["json"]
    plug :authenticate_user_flexible
  end

  pipeline :graphql do
    plug Web.Plugs.ValidateHeaders
  end

  pipeline :dev do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Web.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Health check endpoint
  scope "/", Web do
    pipe_through :public_api

    get "/health", HealthController, :index
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:core, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    # Development tools (unauthenticated)
    scope "/dev" do
      pipe_through :dev
      live_dashboard "/dashboard", metrics: Web.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Signin routes (unprotected)
  scope "/", Web do
    pipe_through [:browser, :redirect_if_authenticated]

    get "/signin", AuthController, :index
    post "/signin", AuthController, :send_magic_link
    get "/signin/token/:token", AuthController, :signin_with_token
  end

  # Protected routes (require authentication)
  scope "/", Web do
    pipe_through [:browser, :require_authenticated]

    get "/", LandingController, :redirect
    get "/leads", LeadsController, :index
    get "/leads/download", LeadsController, :download
    get "/icons.svg", IconsController, :index
    get "/favicon/*path", FaviconController, :serve

    # Catch-all route for undefined paths
    get "/*path", LandingController, :redirect
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

  # Protected API routes (session auth required)
  scope "/api", Web do
    pipe_through :api

    resources "/documents", DocumentController, only: [:create]

    post "/organizations/:organization_id/documents",
         DocumentController,
         :create

    get "/organizations/:organization_id/documents", DocumentController, :index
  end

  # Bearer token authenticated API routes
  scope "/api/v1", Web do
    pipe_through :bearer_api_read

    # Read-only endpoints
    get "/organizations/:organization_id/documents", DocumentController, :index
  end

  scope "/api/v1", Web do
    pipe_through :bearer_api_write

    # Write endpoints
    post "/organizations/:organization_id/documents",
         DocumentController,
         :create

    resources "/documents", DocumentController,
      only: [:create, :update, :delete]
  end

  # Flexible authentication (supports both session and Bearer token)
  scope "/api/v1", Web do
    pipe_through :flexible_api

    # Endpoints that work with both web sessions and API tokens
    # get "/user/profile", UserController, :profile
  end

  # API token management (requires session authentication for security)
  scope "/api", Web do
    pipe_through :api

    resources "/tokens", ApiTokenController,
      only: [:index, :create, :show, :update, :delete]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:core, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: Web.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
