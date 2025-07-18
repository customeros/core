defmodule Core.WebTracker.Sessions.UtmCampaigns do
  @moduledoc """
  Handles UTM campaign parameter tracking and analysis for web sessions.

  This module is responsible for:
  - Parsing and validating UTM parameters
  - Tracking campaign sources, mediums, and terms
  - Standardizing UTM parameter formats
  - Supporting campaign attribution analysis
  """
  alias Core.Repo
  alias Core.WebTracker.Sessions.UtmCampaign

  @err_not_found {:error, "utm campaign not found"}

  def get_by_hash(hash) do
    case Repo.get_by(UtmCampaign, utm_hash: hash) do
      %UtmCampaign{} = campaign -> {:ok, campaign}
      nil -> @err_not_found
    end
  end

  def upsert(attrs) when is_map(attrs) do
    changeset = UtmCampaign.changeset(%UtmCampaign{}, attrs)
    hash = Ecto.Changeset.get_field(changeset, :utm_hash)
    now = DateTime.truncate(DateTime.utc_now(), :second)

    case get_by_hash(hash) do
      {:ok, existing_campaign} ->
        existing_campaign
        |> UtmCampaign.changeset(attrs)
        |> Ecto.Changeset.put_change(:last_seen_at, now)
        |> Repo.update()

      {:error, _} ->
        changeset
        |> Repo.insert()
    end
  end
end
