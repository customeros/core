defmodule Core.Integrations.Providers.GoogleAds.Customers do
  @moduledoc """
  Google Ads customer (client account) operations.

  This module provides functions for interacting with Google Ads customer accounts,
  including listing accessible customer IDs under a manager account.
  """

  require Logger
  alias Core.Integrations.Connection
  alias Core.Integrations.Providers.GoogleAds.Client

  @doc """
  Lists accessible customer IDs under a manager account.

  ## Parameters
    - connection - The integration connection

  ## Returns
    - `{:ok, [map()]}` - List of customer accounts with their details
    - `{:error, term()}` - Error reason
  """
  def list_accessible_customers(%Connection{} = connection) do
    config = Application.get_env(:core, :google_ads)
    api_version = config[:api_version]

    query = """
    SELECT
      customer_client.resource_name,
      customer_client.client_customer,
      customer_client.level,
      customer_client.manager,
      customer_client.descriptive_name,
      customer_client.currency_code,
      customer_client.time_zone,
      customer_client.id
    FROM customer_client
    WHERE customer_client.manager = FALSE
    """

    # Pass the manager account ID as both the customer ID and login-customer-id
    manager_id = connection.external_system_id

    case Client.post(
           connection,
           "/#{api_version}/customers/#{manager_id}/googleAds:searchStream",
           %{query: query},
           %{},
           manager_id
         ) do
      {:ok, response} ->
        case response do
          [%{"results" => results} | _] when is_list(results) ->
            customers = Enum.map(results, &extract_customer_data/1)
            {:ok, customers}

          %{"results" => results} when is_list(results) ->
            customers = Enum.map(results, &extract_customer_data/1)
            {:ok, customers}

          other ->
            Logger.warning(
              "Unexpected Google Ads response format: #{inspect(other)}"
            )

            {:ok, []}
        end

      {:error, reason} ->
        Logger.error(
          "Failed to list Google Ads customer IDs: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Gets the first non-manager client account.

  ## Parameters
    - connection - The integration connection

  ## Returns
    - `{:ok, map()}` - Client account details
    - `{:error, term()}` - Error reason
  """
  def get_client_account(%Connection{} = connection) do
    case list_accessible_customers(connection) do
      {:ok, [customer | _]} -> {:ok, customer}
      {:ok, []} -> {:error, :no_client_accounts}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions

  defp extract_customer_data(%{"customerClient" => client}) do
    %{
      "id" => client["id"],
      "resource_name" => client["resourceName"],
      "descriptive_name" => client["descriptiveName"],
      "currency_code" => client["currencyCode"],
      "time_zone" => client["timeZone"],
      "level" => client["level"],
      "manager" => client["manager"]
    }
  end
end
