defmodule Core.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    topologies = [
      core_cluster: [
        strategy: Cluster.Strategy.Epmd,
        config: [
          hosts: get_cluster_nodes()
        ]
      ]
    ]

    OpentelemetryPhoenix.setup(adapter: :bandit)

    OpentelemetryEcto.setup([:core, :repo], db_statement: :enabled)

    Logger.add_backend(Core.Notifications.CrashMonitor)

    children = [
      {Cluster.Supervisor, [topologies, [name: Core.ClusterSupervisor]]},
      {Phoenix.PubSub, name: Core.PubSub},
      {Task.Supervisor, name: Core.TaskSupervisor},
      Core.Repo,
      Core.Auth.Users.ColorManager,
      Core.Auth.MagicLinkUsageChecker,
      Core.Crm.Companies.CompanyEnricher,
      Core.Crm.Companies.CompanyScrapinEnricher,
      Core.Crm.Companies.CompanyDomainProcessor,
      Core.Crm.Leads.LeadCreator,
      Core.Crm.TargetPersonas.TargetPersonaLinkedinProcessor,
      Core.Crm.Leads.IcpFitEvaluator,
      Core.Crm.Leads.StageEvaluator,
      Core.Crm.Leads.DailyLeadSummarySender,
      Core.Crm.Leads.BriefCreator,
      Core.Integrations.Providers.HubSpot.CompaniesSyncJob,
      Core.WebTracker.SessionCloser,
      Core.Crm.Industries,
      Core.Crm.Contacts.Enricher.BetterContactJobChecker,
      Core.Crm.Contacts.Enricher.ContactEnricher,
      Core.Analytics.JobProcessor,
      Core.Analytics.GoogleAds.CampaignsDailyFetcher,
      Web.Endpoint,
      Web.Presence,
      Web.Telemetry,

      ## 3rd party
      {DNSCluster,
       query: Application.get_env(:core, :dns_cluster_query) || :ignore},
      {Finch,
       name: Core.Finch,
       pools: %{
         default: [
           size: 40,
           count: 4,
           conn_opts: [
             transport_opts: [
               verify: :verify_peer,
               cacerts: :public_key.cacerts_get(),
               customize_hostname_check: [
                 match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
               ]
             ]
           ]
         ]
       }},
      {Finch,
       name: Core.FinchRelaxedTLS,
       pools: %{
         default: [
           size: 10,
           count: 2,
           conn_opts: [
             transport_opts: [
               verify: :verify_none
             ]
           ]
         ]
       }}
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
    result = Supervisor.start_link(children, opts)

    # Initialize bot detector after supervisor starts
    Core.WebTracker.BotDetector.init()

    result
  end

  defp get_cluster_nodes do
    case System.get_env("CLUSTER_NODES") do
      nil ->
        []

      nodes_string ->
        nodes_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&String.to_atom/1)
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
