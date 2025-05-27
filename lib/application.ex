defmodule Core.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryEcto.setup([:core, :repo])

    children = [
      Supervisor.child_spec({Phoenix.PubSub, name: Core.PubSub},
        id: :core_pubsub
      ),
      {Task.Supervisor, name: Core.Researcher.IcpFitEvaluator.Supervisor},
      {Task.Supervisor, name: Core.Researcher.Crawler.Supervisor},
      {Task.Supervisor, name: Core.Researcher.Scraper.Supervisor},
      {Task.Supervisor, name: Core.Researcher.IcpBuilder.Supervisor},
      {Task.Supervisor, name: Core.Ai.Supervisor},
      Core.Auth.Users.ColorManager,
      Core.Repo,
      Core.Researcher.Orchestrator,
      Core.Crm.Companies.Enrich,
      Core.Crm.Companies.CompanyEnricher,
      Core.WebTracker.WebSessionCloser,
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

    opts = [strategy: :one_for_one, name: Core.Supervisor]
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
