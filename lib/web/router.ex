defmodule Web.Router do
  use Web, :router

  import Web.UserAuth

  pipeline :browser do
    plug :accepts, ["html", "json"] # TODO alexb temporal usage
    # plug :accepts, ["html"]
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

  pipeline :cors_limited_api do
    plug :accepts, ["json"]
    plug Web.Plugs.CorsPlug
  end

  pipeline :cors_event_api do
    plug :accepts, ["json"]
    plug Web.Plugs.EventsCorsPlug
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

  # Health check endpoint
  scope "/", Web do
    pipe_through :public_api

    get "/health", HealthController, :index
  end

  scope "/", Web do
    pipe_through :browser

    get "/documents/:id", DocumentController, :index
  end

  # Signin routes (unprotected)
  scope "/", Web do
    pipe_through [:browser, :redirect_if_authenticated]

    get "/signin", AuthController, :index
    post "/signin", AuthController, :send_magic_link
    get "/signin/token/:token", AuthController, :signin_with_token
    get "/signup/token/:token", AuthController, :signup_with_token
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:core, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: Web.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Protected routes (require authentication)
  scope "/", Web do
    pipe_through [:browser, :require_authenticated]

    get "/", LandingController, :redirect
    get "/icons.svg", IconsController, :index
    get "/favicon/*path", FaviconController, :serve
    get "/welcome", WelcomeController, :index

    scope "/leads" do
      get "/", LeadsController, :index
      get "/download", LeadsController, :download
    end

    scope "/tenants" do
      get "/", TenantController, :index
      post "/switch", TenantController, :switch
    end

    scope "/hubspot" do
      get "/connect", HubspotController, :connect
      get "/callback", HubspotController, :callback
      get "/disconnect", HubspotController, :disconnect
    end

    scope "/contacts" do
      get "/", ContactsController, :index
    end
  end

  # V1 API endpoints
  scope "/v1", Web do
    pipe_through :public_api
  end

  # V1 Event endpoint
  scope "/v1", Web do
    pipe_through :cors_event_api

    post "/events", WebTrackerController, :create
  end

  # ICP endpoint with CORS
  scope "/v1", Web do
    pipe_through :cors_limited_api

    post "/icp", IcpController, :create
    options "/*path", IcpController, :options
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

  # Webhook route (restored for controller processing)
  scope "/hubspot", Web do
    pipe_through :public_api

    post "/webhook", HubspotWebhookController, :webhook
  end
end
