defmodule Core.Integrations.Providers.GoogleAds.Campaigns do
  @moduledoc """
  Google Ads campaigns operations.

  This module provides functions for interacting with Google Ads campaigns,
  including listing campaigns and campaign management.
  """

  require Logger
  alias Core.Integrations.Connection
  alias Core.Integrations.Providers.GoogleAds.Client
  alias Core.Integrations.Providers.GoogleAds.Customers

  @doc """
  Lists campaigns for a Google Ads account.

  If the account is a manager account, this will list campaigns from all accessible client accounts.

  ## Parameters
    - connection - The integration connection

  ## Returns
    - `{:ok, [map()]}` - List of campaigns
    - `{:error, term()}` - Error reason

  ## Examples

      iex> list_campaigns(connection)
      {:ok, [
        %{
          "id" => "123456789",
          "name" => "Summer Sale Campaign",
          "status" => "ENABLED",
          "budget_amount_micros" => "1000000",
          "start_date" => "2023-01-01",
          "end_date" => "2023-12-31",
          "advertising_channel_type" => "SEARCH",
          "advertising_channel_sub_type" => "SEARCH_MOBILE_APP"
        }
      ]}
  """
  def list_campaigns(%Connection{} = connection) do
    # The manager account ID is 4146096454
    manager_id = "4146096454"
    # The client account ID is stored in external_system_id
    client_id = connection.external_system_id

    # Get campaigns from the client account using manager account for auth
    case list_campaigns_for_customer(connection, client_id, manager_id) do
      {:ok, campaigns} -> {:ok, campaigns}
      {:error, reason} ->
        Logger.error("Failed to list Google Ads campaigns in client account: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Lists campaigns for a specific customer ID.

  ## Parameters
    - connection - The integration connection
    - customer_id - The customer ID to query campaigns for
    - login_customer_id - The manager account ID to use for authentication (optional)

  ## Returns
    - `{:ok, [map()]}` - List of campaigns
    - `{:error, term()}` - Error reason
  """
  def list_campaigns_for_customer(%Connection{} = connection, customer_id, login_customer_id \\ nil) do
    config = Application.get_env(:core, :google_ads)
    api_version = config[:api_version]

    Logger.info("Querying campaigns for customer ID: #{customer_id}")

    # For test accounts, we only query basic campaign data without metrics
    # to avoid REQUESTED_METRICS_FOR_MANAGER error
    query = """
    SELECT
      campaign.id,
      campaign.name,
      campaign.status,
      campaign.advertising_channel_type,
      campaign.advertising_channel_sub_type,
      campaign.start_date,
      campaign.end_date,
      campaign.optimization_score
    FROM campaign
    ORDER BY campaign.id
    """

    case Client.post(
           connection,
           "/#{api_version}/customers/#{customer_id}/googleAds:searchStream",
           %{query: query},
           %{},
           login_customer_id
         ) do
      {:ok, response} ->
        Logger.info("Got response for customer #{customer_id}: #{inspect(response)}")

        # Handle the stream response format
        campaigns = case response do
          [%{"results" => results} | _] when is_list(results) ->
            Enum.map(results, &extract_campaign_data/1)

          [_ | _] = results when is_list(results) ->
            # Handle case where results are directly in the list
            Enum.flat_map(results, fn
              %{"campaign" => _} = result -> [extract_campaign_data(result)]
              _ -> []
            end)

          %{"results" => results} when is_list(results) ->
            Enum.map(results, &extract_campaign_data/1)

          _ ->
            Logger.warning("No campaigns found in response: #{inspect(response)}")
            []
        end

        {:ok, campaigns}

      {:error, reason} ->
        Logger.error("Failed to list Google Ads campaigns for customer #{customer_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Gets a specific campaign by ID.

  ## Parameters
    - connection - The integration connection
    - campaign_id - The campaign ID

  ## Returns
    - `{:ok, map()}` - Campaign data
    - `{:error, term()}` - Error reason
  """
  def get_campaign(%Connection{} = connection, campaign_id) do
    customer_id = connection.external_system_id

    case Client.get(
           connection,
           "/customers/#{customer_id}/googleAds:searchStream",
           %{
             query: """
             SELECT
               campaign.id,
               campaign.name,
               campaign.status,
               campaign.start_date,
               campaign.end_date,
               campaign.advertising_channel_type,
               campaign.advertising_channel_sub_type
             FROM campaign
             WHERE campaign.id = #{campaign_id}
             """
           }
         ) do
      {:ok, %{"results" => [campaign | _]}} ->
        {:ok, extract_campaign_data(campaign)}

      {:ok, %{"results" => []}} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error(
          "Failed to get Google Ads campaign #{campaign_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # Private functions

  defp extract_campaign_data(%{"campaign" => campaign}) do
    %{
      "id" => campaign["id"],
      "name" => campaign["name"],
      "status" => campaign["status"],
      "advertising_channel_type" => campaign["advertisingChannelType"],
      "advertising_channel_sub_type" => campaign["advertisingChannelSubType"],
      "start_date" => campaign["startDate"],
      "end_date" => campaign["endDate"],
      "optimization_score" => campaign["optimizationScore"],
      "resource_name" => campaign["resourceName"]
    }
  end
end
