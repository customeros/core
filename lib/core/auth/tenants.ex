defmodule Core.Auth.Tenants do
  @moduledoc """
  The Tenants context.
  """

  import Ecto.Query, warn: false
  require Logger
  alias Core.Repo
  alias Core.Auth.Tenants.Tenant
  alias Core.Notifications.Slack
  alias Core.Crm.Companies
  alias Core.Utils.Media.Images

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

  @spec set_tenant_workspace_name(binary(), binary()) :: :ok | {:error, any()}
  def set_tenant_workspace_name(tenant_id, workspace_name)
      when is_binary(tenant_id) do
    case get_tenant_by_id(tenant_id) do
      {:ok, tenant} ->
        tenant
        |> Tenant.changeset(%{workspace_name: workspace_name})
        |> Repo.update()
        |> case do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.error(
              "Failed to update tenant workspace name for #{tenant.name}: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, :not_found} ->
        {:error, :tenant_not_found}
    end
  end

  @spec set_tenant_workspace_icon_key(binary(), binary()) ::
          :ok | {:error, any()}
  defp set_tenant_workspace_icon_key(tenant_id, icon_key)
       when is_binary(tenant_id) do
    case get_tenant_by_id(tenant_id) do
      {:ok, tenant} ->
        tenant
        |> Tenant.changeset(%{workspace_icon_key: icon_key})
        |> Repo.update()
        |> case do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.error(
              "Failed to update tenant workspace icon for #{tenant.name}: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, :not_found} ->
        {:error, :tenant_not_found}
    end
  end

  ## Tenant registration

  def create_tenant(name, domain) do
    OpenTelemetry.Tracer.with_span "tenants.create_tenant" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.name", name},
        {"tenant.domain", domain}
      ])

      case %Tenant{}
           |> Tenant.changeset(%{name: name, domain: domain})
           |> Repo.insert() do
        {:ok, tenant} = result ->
          notify_slack_new_tenant(tenant)
          process_company_for_tenant(tenant)
          OpenTelemetry.Tracer.set_status(:ok)
          result

        error ->
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
        # start ICP building in background
        Task.Supervisor.start_child(
          Core.Researcher.IcpBuilder.Supervisor,
          fn -> Core.Researcher.IcpBuilder.build_for_tenant(tenant_id) end
        )

        {:ok, tenant_id}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp notify_slack_new_tenant(tenant) do
    span_ctx = OpenTelemetry.Tracer.current_span_ctx()

    Task.start(fn ->
      OpenTelemetry.Tracer.set_current_span(span_ctx)

      OpenTelemetry.Tracer.with_span "tenants.notify_slack_new_tenant" do
        case Slack.notify_new_tenant(tenant.name, tenant.domain) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.error(
              "Failed to send Slack notification for tenant #{tenant.name} creation: #{inspect(reason)}"
            )

            OpenTelemetry.Tracer.set_status(:error, "slack_notification_failed")
        end
      end
    end)
  end

  defp process_company_for_tenant(tenant) do
    span_ctx = OpenTelemetry.Tracer.current_span_ctx()

    Task.start(fn ->
      OpenTelemetry.Tracer.set_current_span(span_ctx)

      OpenTelemetry.Tracer.with_span "tenants.process_company_for_tenant" do
        case Companies.get_or_create_by_domain(tenant.domain) do
          {:ok, company} ->
            # If company was just created (no enrichment timestamps), wait a bit for enrichment
            if is_nil(company.name_enrich_attempt_at) or
                 is_nil(company.icon_enrich_attempt_at) do
              # Wait up to 15 seconds for enrichment to complete
              Process.sleep(15_000)
              # Fetch fresh company data
              case Repo.get(Companies.Company, company.id) do
                nil ->
                  :ok

                updated_company ->
                  set_workspace_data_from_company(tenant, updated_company)
              end
            else
              set_workspace_data_from_company(tenant, company)
            end

            :ok

          {:error, reason} ->
            Logger.error(
              "Failed to create company for tenant #{tenant.name}: #{inspect(reason)}"
            )
        end
      end
    end)
  end

  defp set_workspace_data_from_company(tenant, company) do
    set_tenant_workspace_name(tenant.id, company.name)
    copy_company_icon_to_tenant(tenant, company)
  end

  defp copy_company_icon_to_tenant(tenant, company)
       when is_binary(company.icon_key) and company.icon_key != "" do
    with cdn_url when not is_nil(cdn_url) <-
           Images.get_cdn_url(company.icon_key),
         {:ok, storage_key} <-
           Images.download_and_store(
             cdn_url,
             %{
               generate_name: true,
               path: "#{tenant.name}/workspace"
             }
           ),
         :ok <- set_tenant_workspace_icon_key(tenant.id, storage_key) do
      :ok
    else
      nil ->
        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to copy company icon to tenant #{tenant.name}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp copy_company_icon_to_tenant(_tenant, _company), do: :ok
end
