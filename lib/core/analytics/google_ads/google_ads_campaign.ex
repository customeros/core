defmodule Core.Analytics.GoogleAds.GoogleAdsCampaign do
  @moduledoc """
  Schema for storing Google Ads campaign data.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "google_ads_campaigns" do
    field(:tenant_id, :string)
    field(:manager_customer_id, :string)
    field(:client_customer_id, :string)
    field(:campaign_id, :string)
    field(:name, :string)
    field(:status, :string)
    field(:advertising_channel_type, :string)
    field(:advertising_channel_sub_type, :string)
    field(:start_date, :date)
    field(:end_date, :date)
    field(:optimization_score, :decimal)
    field(:raw_data, :map)

    timestamps()
  end

  @required_fields ~w(tenant_id manager_customer_id client_customer_id campaign_id name)a
  @optional_fields ~w(status advertising_channel_type advertising_channel_sub_type start_date end_date optimization_score raw_data)a

  @doc """
  Creates a changeset for a Google Ads campaign.
  """
  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(
      [:tenant_id, :manager_customer_id, :client_customer_id, :campaign_id],
      name:
        :google_ads_campaigns_tenant_id_manager_customer_id_client_custom_index
    )
  end

  @doc """
  Creates a changeset for upserting a Google Ads campaign.
  Ensures updated_at is always touched even if no fields changed.
  """
  def upsert_changeset(campaign, attrs) do
    campaign
    |> changeset(attrs)
    |> force_change(:updated_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
  end
end
