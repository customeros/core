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
    - `{:ok, [String.t()]}` - List of customer IDs
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

    case Client.post(
           connection,
           "/#{api_version}/customers/#{connection.external_system_id}/googleAds:searchStream",
           %{query: query}
         ) do
      {:ok, response} ->
        case response do
          %{"results" => results} ->
            customer_ids = Enum.map(results, fn result ->
              get_in(result, ["customerClient", "id"])
            end)
            {:ok, customer_ids}

          other ->
            Logger.warning("Unexpected Google Ads response format: #{inspect(other)}")
            {:ok, []}
        end

      {:error, reason} ->
        Logger.error("Failed to list Google Ads customer IDs: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
