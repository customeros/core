defmodule Core.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)

    children = [
      {Phoenix.PubSub, name: Realtime.PubSub},

      Core.Icp.Service,
      Core.Realtime.ColorManager,
      Core.Realtime.StoreManager,
      Core.Repo,
      Core.Scraper.Service,
      Web.Endpoint,
      Web.Presence,
      Web.Telemetry,

      ## 3rd party
      {DNSCluster,
       query: Application.get_env(:core, :dns_cluster_query) || :ignore},
      {Finch, name: Core.Finch}
    ]

    env = Application.get_env(:core, :app_env, :prod)

    children =
      if env != :test do
        children ++
          []
      else
        children
      end

    opts = [strategy: :one_for_one, name: Core.Realtime.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
