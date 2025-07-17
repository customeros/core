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

    # Query to get all campaigns with metrics
    campaigns_query = """
    SELECT
      campaign.id,
      campaign.name,
      campaign.status,
      campaign.advertising_channel_type,
      campaign.advertising_channel_sub_type,
      campaign.start_date,
      campaign.end_date,
      campaign.optimization_score,
      campaign.resource_name,
      campaign.serving_status,
      campaign.payment_mode,
      campaign.bidding_strategy_type,
      campaign_budget.amount_micros,
      metrics.cost_micros,
      metrics.impressions,
      metrics.clicks,
      metrics.conversions,
      metrics.conversions_value,
      metrics.average_cpc,
      metrics.ctr
    FROM campaign
    """

    # Query to get ad groups
    ad_groups_query = """
    SELECT
      ad_group.id,
      ad_group.name,
      ad_group.status,
      ad_group.type,
      ad_group.resource_name,
      ad_group.campaign,
      campaign.resource_name
    FROM ad_group
    """

    # Query to get ads
    ads_query = """
    SELECT
      ad_group_ad.ad.id,
      ad_group_ad.ad.name,
      ad_group_ad.ad.type,
      ad_group_ad.ad.final_urls,
      ad_group_ad.status,
      ad_group_ad.resource_name,
      ad_group_ad.ad_group,
      ad_group.resource_name,
      metrics.cost_micros,
      metrics.impressions,
      metrics.clicks,
      metrics.conversions,
      metrics.conversions_value,
      metrics.average_cpc,
      metrics.ctr,
      ad_group_ad.ad.responsive_search_ad.headlines,
      ad_group_ad.ad.responsive_search_ad.descriptions,
      ad_group_ad.ad.image_ad.image_url,
      ad_group_ad.ad.display_url
    FROM ad_group_ad
    """

    # Execute all queries and merge results
    with {:ok, campaigns_response} <-
           Client.post(
             connection,
             "/#{api_version}/customers/#{customer_id}/googleAds:searchStream",
             %{query: campaigns_query},
             %{},
             customer_id
           ),
         {:ok, ad_groups_response} <-
           Client.post(
             connection,
             "/#{api_version}/customers/#{customer_id}/googleAds:searchStream",
             %{query: ad_groups_query},
             %{},
             customer_id
           ),
         {:ok, ads_response} <-
           Client.post(
             connection,
             "/#{api_version}/customers/#{customer_id}/googleAds:searchStream",
             %{query: ads_query},
             %{},
             customer_id
           ) do
      # Process responses and build the complete structure
      campaigns = process_campaign_response(campaigns_response)
      ad_groups = process_ad_groups_response(ad_groups_response)
      ads = process_ads_response(ads_response)

      # Link everything together
      campaigns_with_structure =
        link_campaign_structure(campaigns, ad_groups, ads)

      {:ok, campaigns_with_structure}
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

  # Private helper to process the campaign response
  defp process_campaign_response(response) do
    case response do
      [%{"results" => results} | _] when is_list(results) ->
        Enum.map(results, &extract_campaign_data/1)

      [_ | _] = results when is_list(results) ->
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
  end

  # Process ad groups response
  defp process_ad_groups_response(response) do
    case response do
      [%{"results" => results} | _] when is_list(results) ->
        Enum.map(results, fn result ->
          ad_group = result["adGroup"]

          %{
            "id" => ad_group["id"],
            "name" => ad_group["name"],
            "status" => ad_group["status"],
            "type" => ad_group["type"],
            "resource_name" => ad_group["resourceName"],
            "campaign_resource_name" => ad_group["campaign"]
          }
        end)

      _ ->
        []
    end
  end

  # Process ads response
  defp process_ads_response(response) do
    case response do
      [%{"results" => results} | _] when is_list(results) ->
        Enum.map(results, fn result ->
          ad_group_ad = result["adGroupAd"]
          ad = ad_group_ad["ad"]
          metrics = Map.get(result, "metrics", %{})

          base_data = %{
            "id" => ad["id"],
            "name" => ad["name"],
            "type" => ad["type"],
            "final_urls" => ad["finalUrls"],
            "status" => ad_group_ad["status"],
            "resource_name" => ad_group_ad["resourceName"],
            "ad_group_resource_name" => ad_group_ad["adGroup"],
            "display_url" => ad["displayUrl"],
            "responsive_search_ad" => %{
              "headlines" => get_in(ad, ["responsiveSearchAd", "headlines"]),
              "descriptions" =>
                get_in(ad, ["responsiveSearchAd", "descriptions"])
            },
            "image_url" => get_in(ad, ["imageAd", "imageUrl"])
          }

          if map_size(metrics) > 0 do
            Map.put(base_data, "metrics", %{
              "cost_micros" => metrics["costMicros"],
              "impressions" => metrics["impressions"],
              "clicks" => metrics["clicks"],
              "conversions" => metrics["conversions"],
              "conversions_value" => metrics["conversionsValue"],
              "average_cpc" => metrics["averageCpc"],
              "ctr" => metrics["ctr"]
            })
          else
            base_data
          end
        end)

      _ ->
        []
    end
  end

  # Link campaigns, ad groups, and ads together
  defp link_campaign_structure(campaigns, ad_groups, ads) do
    # First, group ads by their ad group resource name
    ads_by_ad_group = Enum.group_by(ads, & &1["ad_group_resource_name"])

    # Then, add ads to their respective ad groups
    ad_groups_with_ads =
      Enum.map(ad_groups, fn ad_group ->
        group_ads = Map.get(ads_by_ad_group, ad_group["resource_name"], [])
        Map.put(ad_group, "ads", group_ads)
      end)

    # Group ad groups by campaign resource name
    ad_groups_by_campaign =
      Enum.group_by(ad_groups_with_ads, & &1["campaign_resource_name"])

    # Finally, add ad groups to their respective campaigns
    Enum.map(campaigns, fn campaign ->
      campaign_ad_groups =
        Map.get(ad_groups_by_campaign, campaign["resource_name"], [])

      Map.put(campaign, "ad_groups", campaign_ad_groups)
    end)
  end

  # Update the extract_campaign_data function to handle metrics again
  defp extract_campaign_data(%{"campaign" => campaign} = data) do
    campaign_budget = Map.get(data, "campaign_budget", %{})
    metrics = Map.get(data, "metrics", %{})

    base_data = %{
      "id" => campaign["id"],
      "name" => campaign["name"],
      "status" => campaign["status"],
      "advertising_channel_type" => campaign["advertisingChannelType"],
      "advertising_channel_sub_type" => campaign["advertisingChannelSubType"],
      "start_date" => campaign["startDate"],
      "end_date" => campaign["endDate"],
      "optimization_score" => campaign["optimizationScore"],
      "resource_name" => campaign["resourceName"],
      "serving_status" => campaign["servingStatus"],
      "payment_mode" => campaign["paymentMode"],
      "bidding_strategy_type" => campaign["biddingStrategyType"],
      "budget_amount_micros" => campaign_budget["amountMicros"]
    }

    if map_size(metrics) > 0 do
      Map.put(base_data, "metrics", %{
        "cost_micros" => metrics["costMicros"],
        "impressions" => metrics["impressions"],
        "clicks" => metrics["clicks"],
        "conversions" => metrics["conversions"],
        "conversions_value" => metrics["conversionsValue"],
        "average_cpc" => metrics["averageCpc"],
        "ctr" => metrics["ctr"]
      })
    else
      base_data
    end
  end
end
