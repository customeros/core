defmodule Core.Integrations.HubSpot.Webhook do
  @moduledoc """
  HubSpot webhook handling.

  This module handles incoming webhooks from HubSpot,
  processing various events like company updates, contact changes, etc.

  ## Usage

  ```elixir
  # Handle incoming webhook
  {:ok, result} = Core.Integrations.HubSpot.Webhook.handle_webhook(:hubspot, webhook_data)
  ```
  """

  @behaviour Core.Integrations.Webhook.Base
  require Logger
  alias Core.Crm.Companies.ExternalCompanies

  @impl true
  def handle_webhook(tenant_id, webhook_data) do
    # Extract the event type from the webhook data
    event_type = get_event_type(webhook_data)

    # Process the webhook based on the event type
    case event_type do
      "company.creation" ->
        handle_company_creation(tenant_id, webhook_data)

      "company.update" ->
        handle_company_update(tenant_id, webhook_data)

      "company.deletion" ->
        handle_company_deletion(tenant_id, webhook_data)

      unknown_event ->
        Logger.info("Received unhandled HubSpot webhook event: #{unknown_event}")
        {:ok, :ignored}
    end
  end

  # Private functions for handling different webhook events

  defp handle_company_creation(tenant_id, webhook_data) do
    company_id = get_object_id(webhook_data)

    Logger.info("Processing HubSpot company creation webhook for company ID: #{company_id}")

    # Fetch the newly created company details from HubSpot
    case Core.Integrations.HubSpot.Company.fetch_company(tenant_id, company_id) do
      {:ok, company_data} ->
        # Create or update the external company record in our database
        create_or_update_external_company(tenant_id, company_data)

      {:error, reason} ->
        Logger.error("Failed to fetch company details for webhook: #{inspect(reason)}")
        {:error, "Failed to process company creation webhook"}
    end
  end

  defp handle_company_update(tenant_id, webhook_data) do
    company_id = get_object_id(webhook_data)

    Logger.info("Processing HubSpot company update webhook for company ID: #{company_id}")

    # Fetch the updated company details from HubSpot
    case Core.Integrations.HubSpot.Company.fetch_company(tenant_id, company_id) do
      {:ok, company_data} ->
        # Create or update the external company record in our database
        create_or_update_external_company(tenant_id, company_data)

      {:error, reason} ->
        Logger.error("Failed to fetch company details for webhook: #{inspect(reason)}")
        {:error, "Failed to process company update webhook"}
    end
  end

  defp handle_company_deletion(tenant_id, webhook_data) do
    company_id = get_object_id(webhook_data)

    Logger.info("Processing HubSpot company deletion webhook for company ID: #{company_id}")

    # Delete the external company record from our database
    case ExternalCompanies.delete_by_external_id(tenant_id, :hubspot, company_id) do
      {:ok, _} ->
        {:ok, :deleted}

      {:error, reason} ->
        Logger.error("Failed to delete external company: #{inspect(reason)}")
        {:error, "Failed to process company deletion webhook"}
    end
  end

  # Helper functions for webhook processing

  defp get_event_type(%{"eventType" => event_type}), do: event_type
  defp get_event_type(_), do: "unknown"

  defp get_object_id(%{"objectId" => id}), do: id
  defp get_object_id(_), do: nil

  defp create_or_update_external_company(tenant_id, company_data) do
    # Check if the external company already exists
    case ExternalCompanies.get_by_external_id(tenant_id, :hubspot, company_data.external_id) do
      nil ->
        # Create a new external company record
        ExternalCompanies.create(%{
          tenant_id: tenant_id,
          name: company_data.name,
          external_id: company_data.external_id,
          provider: :hubspot,
          data: company_data
        })

      external_company ->
        # Update the existing external company record
        ExternalCompanies.update(external_company, %{
          name: company_data.name,
          data: company_data
        })
    end
  end
end
