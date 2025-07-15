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

  If the account is a manager account, this will list campaigns from all available client accounts.

  ## Parameters
    - connection - The integration connection

  ## Returns
    - `{:ok, [map()]}` - List of campaigns with client account information
    - `{:error, term()}` - Error reason
  """
  def list_campaigns(%Connection{} = connection) do
    # Get all client accounts
    with {:ok, clients} <- Customers.list_accessible_customers(connection) do
      # Get campaigns from each client account in parallel
      campaigns_results =
        Task.async_stream(
          clients,
          fn client ->
            client_id = client["id"]

            Logger.info(
              "Fetching campaigns for client account '#{client["descriptive_name"]}' (#{client_id})"
            )

            case list_campaigns_for_customer(connection, client_id) do
              {:ok, campaigns} ->
                # Add client account info to each campaign
                Enum.map(campaigns, fn campaign ->
                  Map.merge(campaign, %{
                    "client_account" => %{
                      "id" => client["id"],
                      "name" => client["descriptive_name"],
                      "currency_code" => client["currency_code"],
                      "time_zone" => client["time_zone"]
                    }
                  })
                end)

              {:error, reason} ->
                Logger.error(
                  "Failed to list Google Ads campaigns in client account #{client_id}: #{inspect(reason)}"
                )

                []
            end
          end,
          timeout: 30_000
        )
        |> Enum.reduce([], fn
          {:ok, campaigns}, acc -> acc ++ campaigns
          _, acc -> acc
        end)

      {:ok, campaigns_results}
    end
  end

  @doc """
  Lists campaigns for a specific customer ID.

  ## Parameters
    - connection - The integration connection
    - customer_id - The customer ID to query campaigns for

  ## Returns
    - `{:ok, [map()]}` - List of campaigns
    - `{:error, term()}` - Error reason
  """
  def list_campaigns_for_customer(%Connection{} = connection, customer_id) do
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
           customer_id
         ) do
      {:ok, response} ->
        Logger.info(
          "Got response for customer #{customer_id}: #{inspect(response)}"
        )

        # Handle the stream response format
        campaigns =
          case response do
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
              Logger.warning(
                "No campaigns found in response: #{inspect(response)}"
              )

              []
          end

        {:ok, campaigns}

      {:error, reason} ->
        Logger.error(
          "Failed to list Google Ads campaigns for customer #{customer_id}: #{inspect(reason)}"
        )

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
