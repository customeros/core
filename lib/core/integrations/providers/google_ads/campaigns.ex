defmodule Core.Integrations.Providers.GoogleAds.Campaigns do
  @moduledoc """
  Google Ads campaigns operations.

  This module provides functions for interacting with Google Ads campaigns,
  including listing campaigns and campaign management.
  """

  require Logger
  alias Core.Integrations.Connection
  alias Core.Integrations.Providers.GoogleAds.Client

  @doc """
  Lists campaigns for a Google Ads account.

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
          "budgetAmountMicros" => "1000000"
        }
      ]}
  """
    def list_campaigns(%Connection{} = connection) do
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
               campaign.budget_amount_micros,
               campaign.start_date,
               campaign.end_date
             FROM campaign
             WHERE campaign.status != 'REMOVED'
             ORDER BY campaign.name
             """
           }
         ) do
      {:ok, %{"results" => results}} ->
        campaigns = Enum.map(results, &extract_campaign_data/1)
        {:ok, campaigns}

      {:ok, response} ->
        Logger.warning(
          "Unexpected Google Ads API response format: #{inspect(response)}"
        )

        {:ok, []}

      {:error, reason} ->
        Logger.error("Failed to list Google Ads campaigns: #{inspect(reason)}")
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
               campaign.budget_amount_micros,
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

  defp extract_campaign_data(campaign_result) do
    campaign = campaign_result["campaign"]

    %{
      "id" => campaign["id"],
      "name" => campaign["name"],
      "status" => campaign["status"],
      "budget_amount_micros" => campaign["budgetAmountMicros"],
      "start_date" => campaign["startDate"],
      "end_date" => campaign["endDate"],
      "advertising_channel_type" => campaign["advertisingChannelType"],
      "advertising_channel_sub_type" => campaign["advertisingChannelSubType"]
    }
  end
end
