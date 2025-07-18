defmodule Core.WebTracker.Sessions.PaidCampaigns do
  @moduledoc """
  Manages paid campaign tracking and persistence.

  This module handles the storage and retrieval of paid campaign data, including:
  - Campaign lookup by unique hash
  - Upsert operations for campaign data
  - Tracking of campaign last seen timestamps

  Used to maintain records of paid marketing campaigns and their interactions.
  """

  alias Core.Repo
  alias Core.WebTracker.Sessions.PaidCampaign

  @err_not_found {:error, "paid campaign not found"}
  @err_no_data {:error, "no paid campaign data provided"}

  def get_by_hash(hash) do
    case Repo.get_by(PaidCampaign, hash: hash) do
      %PaidCampaign{} = campaign -> {:ok, campaign}
      nil -> @err_not_found
    end
  end

  def upsert(nil), do: @err_no_data

  def upsert(attrs) when is_map(attrs) do
    changeset = PaidCampaign.changeset(%PaidCampaign{}, attrs)
    hash = Ecto.Changeset.get_field(changeset, :hash)
    now = DateTime.truncate(DateTime.utc_now(), :second)

    case get_by_hash(hash) do
      {:ok, existing_campaign} ->
        existing_campaign
        |> PaidCampaign.changeset(attrs)
        |> Ecto.Changeset.put_change(:last_seen_at, now)
        |> Repo.update()

      {:error, _} ->
        changeset
        |> Repo.insert()
    end
  end
end
