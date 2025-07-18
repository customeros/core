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
  require OpenTelemetry.Tracer

  alias Core.Utils.Retry
  alias Core.Utils.TaskAwaiter
  alias Core.Researcher.IcpBuilder.ProfileWriter
  alias Core.Researcher.IcpProfiles
  alias Core.Researcher.Crawler
  alias Core.Researcher.Scraper
  alias Core.Utils.Tracing

  @crawl_timeout 5 * 60 * 1000
  @max_retries 2

  def tenant_icp_start(tenant_record) do
    Task.Supervisor.start_child(
      Core.TaskSupervisor,
      fn ->
        tenant_icp(tenant_record)
      end
    )
  end

  def tenant_icp(tenant_record) do
    case build_icp_with_retry(tenant_record.domain, tenant_record.id) do
      {:ok, profile} ->
        Core.Researcher.IcpFinder.find_matching_companies_start(profile.id)
        {:ok, profile}

      {:error, reason} ->
        Logger.error("Generating Tenant ICP failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def build_icp_with_retry(domain, tenant_id) do
    Retry.with_delay(fn -> build_icp(domain, tenant_id) end, @max_retries)
  end

  def build_icp_fast(domain) do
    OpenTelemetry.Tracer.with_span "icp_builder.build_icp_fast" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.domain", domain}
      ])

      Task.start(fn ->
        Core.Notifications.Slack.notify_new_icp_request(domain)
      end)

      case IcpProfiles.get_by_domain(domain) do
        {:ok, existing_profile} ->
          {:ok, existing_profile}

        {:error, _} ->
          with {:ok, _content} <- Scraper.scrape_webpage(domain),
               {:ok, profile} <- generate_and_save(domain) do
            {:ok, profile}
          else
            {:error, reason} ->
              Logger.error(
                "Could not build fast ICP: #{inspect(reason)}",
                company_domain: domain
              )

              {:error, reason}
          end
      end
    end
  end

  # private
  defp build_icp(domain, tenant_id) do
    task = Crawler.crawl_supervised(domain)

    case TaskAwaiter.await(task, @crawl_timeout) do
      {:ok, _response} ->
        generate_and_save(domain, tenant_id)

      {:error, reason} ->
        Logger.error("ICP builder failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_and_save(domain) do
    generate_and_save(domain, nil)
  end

  defp generate_and_save(domain, tenant_id) do
    OpenTelemetry.Tracer.with_span "icp_builder.generate_and_save" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.domain", domain},
        {"param.tenant_id", tenant_id}
      ])

      with {:ok, icp} <- ProfileWriter.generate_icp(domain),
           {:ok, profile} <- save_icp(domain, icp, tenant_id) do
        {:ok, profile}
      else
        {:error, reason} ->
          Tracing.error(
            reason,
            "Could not generate and save ICP",
            company_domain: domain
          )

          {:error, reason}
      end
    end
  end

  defp save_icp(domain, icp_output, tenant_id) do
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
