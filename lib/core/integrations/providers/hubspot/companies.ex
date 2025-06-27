defmodule Core.Integrations.Providers.HubSpot.Companies do
  @moduledoc """
  HubSpot company integration.

  This module handles the synchronization of companies from HubSpot to our system.
  It provides functions for:
  - Fetching companies from HubSpot
  - Syncing company data between systems
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Core.Integrations.Providers.HubSpot.Client
  alias Core.Integrations.Connection
  alias Core.Integrations.Connections
  alias Core.Integrations.Providers.HubSpot.HubSpotCompany
  alias Core.Utils.Tracing

  @customer_property_names ["customer_status", "type"]
  @customer_property_value "customer"
  @additional_properties ["name", "domain"] ++ @customer_property_names

  def additional_properties do
    @additional_properties
  end

  @doc """
  Lists companies from HubSpot.

  ## Examples

      iex> list_hubspot_companies(connection)
      {:ok, %{"results" => [...]}}

      iex> list_hubspot_companies(connection, %{limit: 10, after: "123"})
      {:ok, %{"results" => [...]}}
  """
  def list_hubspot_companies(%Connection{} = connection, params \\ %{}) do
    Logger.info(
      "[HubSpot Company] Listing companies for connection #{connection.id} with params: #{inspect(params)}"
    )

    case Client.get(connection, "/crm/v3/objects/companies", params) do
      {:ok, response} ->
        # API call succeeded - connection is healthy, update status to active
        case Connections.update_status(connection, :active) do
          {:ok, _} ->
            Logger.debug(
              "[HubSpot Company] Successfully listed companies and updated connection status to active"
            )

            {:ok, response}

          {:error, reason} ->
            Logger.warning(
              "[HubSpot Company] Listed companies but failed to update connection status: #{inspect(reason)}"
            )

            {:ok, response}
        end

      {:error, reason} ->
        Logger.error(
          "[HubSpot Company] Error listing companies: #{inspect(reason)}"
        )

        # API call failed - update connection status to error
        case Connections.update_status(connection, :error) do
          {:ok, _} ->
            Logger.debug(
              "[HubSpot Company] Updated connection status to error due to API failure"
            )

          {:error, update_reason} ->
            Logger.warning(
              "[HubSpot Company] Failed to update connection status to error: #{inspect(update_reason)}"
            )
        end

        {:error, reason}
    end
  end

  @doc """
  Fetches a company from HubSpot by tenant ID and company ID.

  Looks up the HubSpot connection for the given tenant, ensures the token is valid (refreshing if needed),
  and fetches the company details from HubSpot.

  ## Examples

      iex> get_company_by_tenant("tenant_123", "456")
      {:ok, %{"id" => "456", ...}}

      iex> get_company_by_tenant("unknown_tenant", "456")
      {:error, :not_found}
  """
  def get_company_by_tenant(tenant_id, company_id)
      when is_binary(tenant_id) and is_binary(company_id) do
    case Connections.get_connection(tenant_id, :hubspot) do
      {:ok, %Connection{} = connection} ->
        get_company(connection, company_id)

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches a company from HubSpot by ID.

  ## Examples

      iex> get_company(connection, "123")
      {:ok, %{"id" => "123", "properties" => %{"name" => "Acme Inc"}}}
  """
  def get_company(%Connection{} = connection, company_id) do
    case Client.get(connection, "/crm/v3/objects/companies/#{company_id}") do
      {:ok, response} ->
        # API call succeeded - connection is healthy, update status to active
        case Connections.update_status(connection, :active) do
          {:ok, _} ->
            Logger.info(
              "[HubSpot Company] Successfully fetched company #{company_id} and updated connection status to active"
            )

            {:ok, response}

          {:error, reason} ->
            Logger.warning(
              "[HubSpot Company] Fetched company #{company_id} but failed to update connection status: #{inspect(reason)}"
            )

            {:ok, response}
        end

      {:error, reason} ->
        Logger.error(
          "[HubSpot Company] Error fetching company #{company_id}: #{inspect(reason)}"
        )

        # API call failed - update connection status to error
        case Connections.update_status(connection, :error) do
          {:ok, _} ->
            Logger.debug(
              "[HubSpot Company] Updated connection status to error due to API failure"
            )

          {:error, update_reason} ->
            Logger.warning(
              "[HubSpot Company] Failed to update connection status to error: #{inspect(update_reason)}"
            )
        end

        {:error, reason}
    end
  end

  @doc """
  Fetches a company from HubSpot by ID with specific properties.

  ## Examples

      iex> get_company_with_properties(connection, "123", ["name", "domain"])
      {:ok, %{"id" => "123", "properties" => %{"name" => "Acme Inc", "domain" => "acme.com"}}}
  """
  def get_company_with_properties(
        %Connection{} = connection,
        company_id,
        additional_properties
      )
      when is_list(additional_properties) do
    properties_param = Enum.join(additional_properties, ",")

    url =
      "/crm/v3/objects/companies/#{company_id}?properties=#{properties_param}"

    case Client.get(connection, url) do
      {:ok, response} ->
        # API call succeeded - connection is healthy, update status to active
        case Connections.update_status(connection, :active) do
          {:ok, _} ->
            Logger.info(
              "[HubSpot Company] Successfully fetched company #{company_id} with properties #{properties_param} and updated connection status to active"
            )

            {:ok, response}

          {:error, reason} ->
            Logger.warning(
              "[HubSpot Company] Fetched company #{company_id} but failed to update connection status: #{inspect(reason)}"
            )

            {:ok, response}
        end

      {:error, reason} ->
        Logger.error(
          "[HubSpot Company] Error fetching company #{company_id} with properties #{properties_param}: #{inspect(reason)}"
        )

        # API call failed - update connection status to error
        case Connections.update_status(connection, :error) do
          {:ok, _} ->
            Logger.debug(
              "[HubSpot Company] Updated connection status to error due to API failure"
            )

          {:error, update_reason} ->
            Logger.warning(
              "[HubSpot Company] Failed to update connection status to error: #{inspect(update_reason)}"
            )
        end

        {:error, reason}
    end
  end

  @spec sync_company(map(), String.t()) ::
          {:ok, %{crm_company: Core.Crm.Companies.Company.t()}}
          | {:error, any()}
  def sync_company(company, tenant_id) do
    OpenTelemetry.Tracer.with_span "hubspot.companies.sync_company" do
      hubspot_company = HubSpotCompany.from_hubspot_map(company)

      OpenTelemetry.Tracer.set_attributes([
        {"hubspot_company.id", hubspot_company.id},
        {"hubspot_company.name", hubspot_company.name},
        {"hubspot_company.domain", hubspot_company.domain},
        {"hubspot_company.archived", hubspot_company.archived},
        {"hubspot_company.customer_status",
         Map.get(hubspot_company.raw_properties, "customer_status")},
        {"hubspot_company.type",
         Map.get(hubspot_company.raw_properties, "type")}
      ])

      Logger.info("[HubSpot Company] Data: #{inspect(hubspot_company)}")

      is_customer = customer_type?(hubspot_company)

      with {:archived, false} <- {:archived, hubspot_company.archived},
           {:is_customer, true} <- {:is_customer, is_customer},
           {:domain, domain} when is_binary(domain) and domain != "" <-
             {:domain, hubspot_company.domain},
           {:ok, crm_company} <-
             Core.Crm.Companies.get_or_create_by_domain(domain),
           {:ok, tenant} <- Core.Auth.Tenants.get_tenant_by_id(tenant_id),
           {:ok, lead} <-
             get_or_create_lead_with_stage(
               tenant.name,
               crm_company.id,
               is_customer
             ),
           {:ok, _updated_lead} <-
             update_lead_stage_for_customer(lead, is_customer) do
        {:ok, %{crm_company: crm_company}}
      else
        {:archived, true} ->
          {:error, :company_archived}

        {:is_customer, false} ->
          {:error, :not_customer}

        {:domain, domain} when is_nil(domain) or domain == "" ->
          {:error, :no_domain}

        {:domain, domain} when not is_binary(domain) ->
          {:error, :invalid_domain_format}

        {:error, :domain_not_reachable} ->
          Tracing.warning(:domain_not_reachable, "Domain not reachable")
          {:error, :domain_not_reachable}

        {:error, :cannot_resolve_url} ->
          Tracing.warning(
            :cannot_resolve_url,
            "Cannot resolve url #{hubspot_company.domain}"
          )

          {:error, :cannot_resolve_url}

        {:error, :cannot_resolve_to_primary_domain} ->
          Tracing.warning(
            :cannot_resolve_to_primary_domain,
            "Cannot resolve to primary domain #{hubspot_company.domain}"
          )

          {:error, :cannot_resolve_to_primary_domain}

        {:error, reason} ->
          Tracing.error(reason, "Error syncing HubSpot company",
            company_domain: hubspot_company.domain,
            external_id: company["id"]
          )

          {:error, reason}

        unexpected ->
          Tracing.error(
            :unexpected_error,
            "Unexpected error in sync_company: #{inspect(unexpected)}"
          )

          {:error, :unexpected_error}
      end
    end
  end

  defp customer_type?(%HubSpotCompany{raw_properties: raw_properties}) do
    Enum.any?(@customer_property_names, fn property_name ->
      case Map.get(raw_properties, property_name) do
        value when is_binary(value) ->
          String.downcase(value) == @customer_property_value

        _ ->
          false
      end
    end)
  end

  defp get_or_create_lead_with_stage(tenant_name, company_id, is_customer) do
    lead_attrs = %{ref_id: company_id, type: :company}

    lead_attrs =
      if is_customer do
        lead_attrs
        |> Map.put(:stage, :customer)
        |> Map.put(:icp_fit, :strong)
      else
        lead_attrs
      end

    Core.Crm.Leads.get_or_create(tenant_name, lead_attrs)
  end

  defp update_lead_stage_for_customer(
         %Core.Crm.Leads.Lead{} = lead,
         is_customer
       ) do
    if is_customer and lead.stage != :customer do
      case Core.Crm.Leads.update_lead(lead, %{
             stage: :customer,
             icp_fit: :strong
           }) do
        {:ok, updated_lead} -> {:ok, updated_lead}
        {:error, reason} -> {:error, reason}
      end
    else
      {:ok, lead}
    end
  end

  @doc """
  Syncs all companies from HubSpot with pagination.

  Fetches companies page by page, gets detailed information for each company,
  and syncs them to the CRM system.

  ## Examples

      iex> sync_companies(connection_id)
      {:ok, %{total_synced: 150, total_pages: 3}}

      iex> sync_companies(connection_id, %{limit: 50})
      {:ok, %{total_synced: 75, total_pages: 2}}
  """
  def sync_companies(connection_id, params \\ %{}, recursive? \\ false) do
    case Connections.get_connection_by_id(connection_id) do
      {:ok, %Connection{} = connection} ->
        # Check if connection is of HubSpot type
        if connection.provider == :hubspot do
          # Only set defaults for parameters that aren't already provided
          sync_params = Map.merge(%{limit: 10}, params)

          Logger.info(
            "[HubSpot Company] Starting sync of all companies for connection #{connection.id} with params: #{inspect(sync_params)}"
          )

          do_sync_companies(connection, sync_params, 0, 0, recursive?)
        else
          Logger.error(
            "[HubSpot Company] Connection #{connection.id} is not a HubSpot connection (provider: #{connection.provider})"
          )

          {:error, :invalid_provider}
        end

      {:error, reason} ->
        Logger.error(
          "[HubSpot Company] Failed to get connection #{connection_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp do_sync_companies(
         %Connection{} = connection,
         params,
         total_synced,
         total_pages,
         recursive?
       ) do
    OpenTelemetry.Ctx.clear()

    OpenTelemetry.Tracer.with_span "hubspot.companies.do_sync_companies" do
      OpenTelemetry.Tracer.set_attributes([
        {"total_synced", total_synced},
        {"total_pages", total_pages},
        {"tenant.id", connection.tenant_id},
        {"connection.id", connection.id},
        {"params", "#{inspect(params)}"}
      ])

      case list_hubspot_companies(connection, params) do
        {:ok, response} ->
          handle_successful_companies_fetch(
            connection,
            response,
            params,
            total_synced,
            total_pages,
            recursive?
          )

        {:error, reason} ->
          Logger.error(
            "[HubSpot Company] Error listing companies during sync: #{inspect(reason)}"
          )

          {:error, reason}
      end
    end
  end

  defp handle_successful_companies_fetch(
         connection,
         %{"results" => companies} = response,
         params,
         total_synced,
         total_pages,
         recursive?
       ) do
    Logger.info(
      "[HubSpot Company] Processing page #{total_pages + 1} with #{length(companies)} companies"
    )

    {synced_count, errors} = process_companies_page(connection, companies)
    updated_total_synced = total_synced + synced_count
    updated_total_pages = total_pages + 1

    log_processing_errors(errors, updated_total_pages)

    case get_next_page_cursor(response) do
      {:ok, after_cursor} ->
        handle_next_page(
          connection,
          params,
          after_cursor,
          updated_total_synced,
          updated_total_pages,
          recursive?
        )

      :no_more_pages ->
        handle_sync_completion(
          connection,
          updated_total_synced,
          updated_total_pages
        )
    end
  end

  defp log_processing_errors(errors, page_number) do
    if length(errors) > 0 do
      Logger.warning(
        "[HubSpot Company] Encountered #{length(errors)} errors while processing page #{page_number}: #{inspect(errors)}"
      )
    end
  end

  defp get_next_page_cursor(%{
         "paging" => %{"next" => %{"after" => after_cursor}}
       })
       when is_binary(after_cursor) do
    {:ok, after_cursor}
  end

  defp get_next_page_cursor(_), do: :no_more_pages

  defp handle_next_page(
         connection,
         params,
         after_cursor,
         updated_total_synced,
         updated_total_pages,
         recursive?
       ) do
    Logger.info("[HubSpot Company] Next page after cursor: #{after_cursor}")

    update_connection_cursor(connection, after_cursor)
    next_params = Map.put(params, :after, after_cursor)

    if recursive? do
      do_sync_companies(
        connection,
        next_params,
        updated_total_synced,
        updated_total_pages,
        true
      )
    else
      {:ok,
       %{total_synced: updated_total_synced, total_pages: updated_total_pages}}
    end
  end

  defp update_connection_cursor(connection, after_cursor) do
    case Connections.update_connection(connection, %{
           company_sync_after: after_cursor
         }) do
      {:ok, _updated_connection} ->
        Logger.debug(
          "[HubSpot Company] Updated connection #{connection.id} company_sync_after to #{after_cursor}"
        )

      {:error, reason} ->
        Tracing.error(
          reason,
          "[HubSpot Company] Failed to update company_sync_after for connection #{connection.id}"
        )
    end
  end

  defp handle_sync_completion(
         connection,
         updated_total_synced,
         updated_total_pages
       ) do
    update_connection_completion_status(connection)

    Logger.info(
      "[HubSpot Company] Completed sync of all companies. Total synced: #{updated_total_synced}, Total pages: #{updated_total_pages}"
    )

    {:ok,
     %{total_synced: updated_total_synced, total_pages: updated_total_pages}}
  end

  defp update_connection_completion_status(connection) do
    case Connections.update_connection(connection, %{
           company_sync_completed: true
         }) do
      {:ok, _updated_connection} ->
        Logger.info(
          "[HubSpot Company] Updated connection #{connection.id} company_sync_completed to true"
        )

      {:error, reason} ->
        Logger.error(
          "[HubSpot Company] Failed to update company_sync_completed for connection #{connection.id}: #{inspect(reason)}"
        )
    end
  end

  defp process_companies_page(connection, companies) do
    Enum.reduce(companies, {0, []}, fn company, {synced_count, errors} ->
      case sync_single_company(connection, company) do
        {:ok, _} ->
          {synced_count + 1, errors}

        {:error, reason} ->
          {synced_count, [reason | errors]}
      end
    end)
  end

  defp sync_single_company(connection, company) do
    company_id = company["id"]

    with {:ok, detailed_company} <-
           get_company_with_properties(
             connection,
             company_id,
             additional_properties()
           ),
         {:ok, crm_company} <-
           sync_company(detailed_company, connection.tenant_id) do
      Logger.debug(
        "[HubSpot Company] Successfully synced company #{company_id} (#{crm_company.crm_company.name})"
      )

      {:ok, crm_company}
    else
      {:error, reason} ->
        Logger.warning(
          "[HubSpot Company] Failed to sync company #{company_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end
end
