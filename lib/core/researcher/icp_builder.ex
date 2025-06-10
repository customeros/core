defmodule Core.Researcher.IcpBuilder do
  @moduledoc """
  Orchestrates the process of building and managing Ideal Customer Profiles (ICPs).

  This module coordinates the creation and management of ICPs by:
  - Crawling company websites to gather data
  - Generating ICP profiles based on the gathered data
  - Managing the ICP creation process for tenants
  - Initiating company matching processes for new ICPs
  """

  require Logger

  alias Core.Researcher.IcpBuilder.ProfileWriter
  alias Core.Researcher.IcpProfiles
  alias Core.Researcher.Crawler
  alias Core.Researcher.Scraper

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
    with {:ok, icp} <- build_icp(tenant_record.domain),
         {:ok, profile} <-
           save_icp(tenant_record.domain, icp, tenant_record.id) do
      Core.Researcher.IcpFinder.find_matching_companies_start(profile.id)
      {:ok, profile}
    else
      {:error, reason} ->
        Logger.error("Generating Tenant ICP failed: #{inspect(reason)}")
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
        Logger.error("Building ICP failed: #{reason}")
        {:error, reason}

      {:ok, {:error, reason}} ->
        Logger.error("Building ICP failed: #{reason}")
        {:error, reason}

      {:exit, reason} ->
        Logger.error("Building ICP crashed: #{reason}")
        {:error, reason}

      nil ->
        {:error, :icp_generation_timeout}
    end
  end

  def build_icp_fast(domain) do
    with {:ok, _homepage} <- Scraper.scrape_webpage(domain),
         {:ok, icp} <-
           ProfileWriter.generate_icp(domain),
         {:ok, _profile} <- save_icp(domain, icp) do
      {:ok, icp}
    else
      {:error, reason} ->
        Logger.error(
          "Ideal Customer Profile generation failed: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp save_icp(domain, icp_output, tenant_id \\ nil) do
    base_attrs = %{
      domain: domain,
      profile: icp_output.icp,
      qualifying_attributes: icp_output.qualifying_attributes
    }

    profile_attrs =
      case tenant_id do
        nil -> base_attrs
        id -> Map.put(base_attrs, :tenant_id, id)
      end

    IcpProfiles.create_profile(profile_attrs)
  end
end
