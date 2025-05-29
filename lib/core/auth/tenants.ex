defmodule Core.Auth.Tenants do
  @moduledoc """
  The Tenants context.
  """

  import Ecto.Query, warn: false
  require Logger
  require OpenTelemetry.Tracer

  alias Core.Repo
  alias Core.Auth.Tenants.Tenant
  alias Core.Notifications.Slack
  alias Core.Crm.Companies
  alias Core.Utils.Media.Images

  @company_enrichment_timeout 15_000

  ## Database getters

  def get_tenant_by_name(name) when is_binary(name) do
    case Repo.get_by(Tenant, name: name) do
      %Tenant{} = tenant -> {:ok, tenant}
      nil -> {:error, :not_found}
    end
  end

  def get_tenant_by_id(tenant_id) when is_binary(tenant_id) do
    case Repo.get_by(Tenant, id: tenant_id) do
      %Tenant{} = tenant -> {:ok, tenant}
      nil -> {:error, :not_found}
    end
  end

  ## Tenant updates

  @spec set_tenant_workspace_name(binary(), binary()) :: :ok | {:error, any()}
  def set_tenant_workspace_name(tenant_id, workspace_name)
      when is_binary(tenant_id) do
    with {:ok, tenant} <- get_tenant_by_id(tenant_id),
         {:ok, _updated_tenant} <-
           update_tenant(tenant, %{workspace_name: workspace_name}) do
      :ok
    else
      {:error, :not_found} -> {:error, :tenant_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec set_tenant_workspace_icon_key(binary(), binary()) ::
          :ok | {:error, any()}
  def set_tenant_workspace_icon_key(tenant_id, icon_key)
      when is_binary(tenant_id) do
    with {:ok, tenant} <- get_tenant_by_id(tenant_id),
         {:ok, _updated_tenant} <-
           update_tenant(tenant, %{workspace_icon_key: icon_key}) do
      :ok
    else
      {:error, :not_found} -> {:error, :tenant_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_tenant(tenant, attrs) do
    tenant
    |> Tenant.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_tenant} ->
        {:ok, updated_tenant}

      {:error, changeset} ->
        Logger.error(
          "Failed to update tenant #{tenant.name}: #{inspect(changeset.errors)}"
        )

        {:error, changeset}
    end
  end

  ## Tenant registration

  def create_tenant(name, domain) do
    OpenTelemetry.Tracer.with_span "tenants.create_tenant" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.name", name},
        {"tenant.domain", domain}
      ])

      case insert_tenant(name, domain) do
        {:ok, tenant} = result ->
          # Start background processes
          start_post_creation_tasks(tenant)
          OpenTelemetry.Tracer.set_status(:ok)
          result

        {:error, _changeset} = error ->
          OpenTelemetry.Tracer.set_status(:error, "creation_failed")
          error
      end
    end
  end

  def create_tenant_and_return_id(name, domain) do
    case create_tenant(name, domain) do
      {:ok, tenant} -> {:ok, tenant.id}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def create_tenant_and_build_icp(name, domain) do
    case create_tenant_and_return_id(name, domain) do
      {:ok, tenant_id} ->
        # Start ICP building in background
        start_icp_building_task(tenant_id)
        {:ok, tenant_id}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  ## Private functions

  defp insert_tenant(name, domain) do
    %Tenant{}
    |> Tenant.changeset(%{name: name, domain: domain})
    |> Repo.insert()
  end

  defp start_post_creation_tasks(tenant) do
    # Start Slack notification
    start_slack_notification_task(tenant)

    # Start company processing
    start_company_processing_task(tenant)
  end

  defp start_slack_notification_task(tenant) do
    span_ctx = OpenTelemetry.Tracer.current_span_ctx()
    Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
      OpenTelemetry.Tracer.set_current_span(span_ctx)
      notify_slack_new_tenant(tenant)
    end)
  end

  defp start_company_processing_task(tenant) do
    span_ctx = OpenTelemetry.Tracer.current_span_ctx()
    Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
      OpenTelemetry.Tracer.set_current_span(span_ctx)
      process_company_for_tenant(tenant)
    end)
  end

  defp start_icp_building_task(tenant_id) do
    Task.Supervisor.start_child(Core.TaskSupervisor, fn ->
      Core.Researcher.IcpBuilder.build_for_tenant(tenant_id)
    end)
  end

  defp notify_slack_new_tenant(tenant) do
    OpenTelemetry.Tracer.with_span "tenants.notify_slack_new_tenant" do
      case Slack.notify_new_tenant(tenant.name, tenant.domain) do
        :ok ->
          Logger.info("Sent Slack notification for new tenant: #{tenant.name}")
          :ok

        {:error, reason} ->
          Logger.error(
            "Failed to send Slack notification for tenant #{tenant.name}: #{inspect(reason)}"
          )

          OpenTelemetry.Tracer.set_status(:error, "slack_notification_failed")
          {:error, reason}
      end
    end
  end

  defp process_company_for_tenant(tenant) do
    OpenTelemetry.Tracer.with_span "tenants.process_company_for_tenant" do
      case Companies.get_or_create_by_domain(tenant.domain) do
        {:ok, company} ->
          company = wait_for_enrichment_if_needed(company)
          set_workspace_data_from_company(tenant, company)

          Logger.info(
            "Successfully processed company for tenant: #{tenant.name}"
          )

          :ok

        {:error, reason} ->
          Logger.error(
            "Failed to create company for tenant #{tenant.name}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    end
  end

  defp wait_for_enrichment_if_needed(company) do
    if needs_enrichment?(company) do
      Logger.info(
        "Waiting for company enrichment to complete: #{company.domain}"
      )

      Process.sleep(@company_enrichment_timeout)

      # Fetch fresh company data after waiting
      case Repo.get(Companies.Company, company.id) do
        nil ->
          Logger.warning(
            "Company #{company.id} disappeared after enrichment wait"
          )

          company

        updated_company ->
          Logger.info("Retrieved updated company data after enrichment wait")
          updated_company
      end
    else
      company
    end
  end

  defp needs_enrichment?(company) do
    is_nil(company.name_enrich_attempt_at) or
      is_nil(company.icon_enrich_attempt_at)
  end

  defp set_workspace_data_from_company(tenant, company) do
    # Set workspace name if company has a name
    if company.name && company.name != "" do
      case set_tenant_workspace_name(tenant.id, company.name) do
        :ok ->
          Logger.info(
            "Set workspace name for tenant #{tenant.name}: #{company.name}"
          )

        {:error, reason} ->
          Logger.error(
            "Failed to set workspace name for tenant #{tenant.name}: #{inspect(reason)}"
          )
      end
    end

    # Copy company icon if available
    copy_company_icon_to_tenant(tenant, company)
  end

  defp copy_company_icon_to_tenant(tenant, company)
       when is_binary(company.icon_key) and company.icon_key != "" do
    with cdn_url when not is_nil(cdn_url) <-
           Images.get_cdn_url(company.icon_key),
         {:ok, storage_key} <- download_and_store_icon(cdn_url, tenant),
         :ok <- set_tenant_workspace_icon_key(tenant.id, storage_key) do
      Logger.info("Successfully copied company icon to tenant: #{tenant.name}")
      :ok
    else
      nil ->
        Logger.info(
          "No CDN URL available for company icon: #{company.icon_key}"
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to copy company icon to tenant #{tenant.name}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp copy_company_icon_to_tenant(_tenant, _company) do
    Logger.debug("No company icon to copy")
    :ok
  end

  defp download_and_store_icon(cdn_url, tenant) do
    Images.download_and_store(cdn_url, %{
      generate_name: true,
      path: "#{tenant.name}/workspace"
    })
  end
end
