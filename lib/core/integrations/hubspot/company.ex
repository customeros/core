defmodule Core.Integrations.HubSpot.Company do
  @moduledoc """
  HubSpot company operations.

  This module handles all company-related operations with HubSpot,
  including fetching companies and individual company details.

  ## Usage

  ```elixir
  # Fetch all companies
  {:ok, companies} = Core.Integrations.HubSpot.Company.fetch_companies(:hubspot)

  # Fetch a specific company
  {:ok, company} = Core.Integrations.HubSpot.Company.fetch_company(:hubspot, "company_id")
  ```
  """

  @behaviour Core.Integrations.Company.Base
  alias Core.Integrations.HubSpot.Client
  alias Core.Integrations.Registry
  require Logger

  @impl true
  def fetch_companies(tenant_id) do
    case Registry.get_connection(tenant_id, :hubspot) do
      nil ->
        {:error, :no_connection}

      connection ->
        fetch_companies_from_hubspot(connection.access_token)
    end
  end

  @impl true
  def fetch_company(tenant_id, company_id) do
    case Registry.get_connection(tenant_id, :hubspot) do
      nil ->
        {:error, :no_connection}

      connection ->
        fetch_company_from_hubspot(connection.access_token, company_id)
    end
  end

  # Private functions for HubSpot API calls

  defp fetch_companies_from_hubspot(token) do
    params = %{
      "limit" => 100,
      "properties" => "name,domain,phone,address,city,state,country,zip"
    }

    case Client.request(:get, "/crm/v3/objects/companies", token: token, params: params) do
      {:ok, response} ->
        case Client.handle_response(response) do
          {:ok, %{"results" => companies}} ->
            formatted_companies = Enum.map(companies, &format_company/1)
            {:ok, formatted_companies}

          {:error, reason} ->
            Logger.error("Failed to fetch HubSpot companies: #{inspect(reason)}")
            {:error, "Failed to fetch companies"}
        end

      {:error, reason} ->
        Logger.error("HubSpot companies request failed: #{inspect(reason)}")
        {:error, "Companies request failed"}
    end
  end

  defp fetch_company_from_hubspot(token, company_id) do
    params = %{
      "properties" => "name,domain,phone,address,city,state,country,zip"
    }

    case Client.request(:get, "/crm/v3/objects/companies/#{company_id}", token: token, params: params) do
      {:ok, response} ->
        case Client.handle_response(response) do
          {:ok, company} ->
            {:ok, format_company(company)}

          {:error, reason} ->
            Logger.error("Failed to fetch HubSpot company: #{inspect(reason)}")
            {:error, "Failed to fetch company"}
        end

      {:error, reason} ->
        Logger.error("HubSpot company request failed: #{inspect(reason)}")
        {:error, "Company request failed"}
    end
  end

  # Helper function to format HubSpot company data
  defp format_company(company) do
    properties = company["properties"] || %{}

    %{
      id: company["id"],
      name: properties["name"],
      domain: properties["domain"],
      phone: properties["phone"],
      address: %{
        street: properties["address"],
        city: properties["city"],
        state: properties["state"],
        country: properties["country"],
        zip: properties["zip"]
      },
      created_at: company["createdAt"],
      updated_at: company["updatedAt"],
      archived: company["archived"] || false,
      external_id: company["id"],
      provider: :hubspot
    }
  end
end
