defmodule Core.Researcher.IcpBuilder do
  alias Core.Researcher.Builder.ProfileWriter
  alias Core.Researcher.Crawler
  alias Core.Auth.Tenants

  @crawl_timeout 5 * 60 * 1000

  def tenant_icp_start(tenant_id) do
    Task.Supervisor.start_child(
      Core.TaskSupervisor,
      fn ->
        tenant_icp(tenant_id)
      end
    )
  end

  def tenant_icp(tenant_id) do
    with {:ok, tenant_record} <- Tenants.get_tenant_by_id(tenant_id),
         {:ok, icp} <- build_icp(tenant_record.domain) do
      profile = %{
        domain: tenant_record.domain,
        tenant_id: tenant_id,
        profile: icp.icp,
        qualifying_attributes: icp.qualifying_attributes
      }

      case Core.Researcher.IcpProfiles.create_profile(profile) do
        {:ok, profile} -> {:ok, profile}
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def build_icp(domain) do
    task = Crawler.crawl_supervised(domain)

    with {:ok, {:ok, _scraped_data}} <- Task.yield(task, @crawl_timeout),
         {:ok, icp} <- ProfileWriter.generate_icp(domain) do
      {:ok, icp}
    else
      {:error, reason} ->
        {:error, reason}

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:exit, reason} ->
        {:error, reason}

      nil ->
        {:error, :icp_generation_timeout}
    end
  end
end
