defmodule Core.Researcher.IcpBuilder do
  @moduledoc """
  Orchestrates the process of building and managing Ideal Customer Profiles (ICPs).

  This module coordinates the creation and management of ICPs by:
  - Crawling company websites to gather data
  - Generating ICP profiles based on the gathered data
  - Managing the ICP creation process for tenants
  - Initiating company matching processes for new ICPs
  """

  alias Core.Researcher.Builder.ProfileWriter
  alias Core.Researcher.Crawler

  @crawl_timeout 5 * 60 * 1000

  def tenant_icp_start(tenant_record) do
    Task.Supervisor.start_child(
      Core.TaskSupervisor,
      fn ->
        tenant_icp(tenant_record)
      end
    )
  end

  def tenant_icp(tenant_record) do
    case build_icp(tenant_record.domain) do
      {:ok, icp} ->
        profile = %{
          domain: tenant_record.domain,
          tenant_id: tenant_record.id,
          profile: icp.icp,
          qualifying_attributes: icp.qualifying_attributes
        }

        case Core.Researcher.IcpProfiles.create_profile(profile) do
          {:ok, profile} ->
            Core.Researcher.IcpFinder.find_matching_companies_start(profile.id)
            {:ok, profile}

          {:error, changeset} ->
            {:error, changeset}
        end

      {:error, reason} ->
        {:error, reason}
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
