defmodule Core.WebTracker.Sessions.PaidCampaigns do
  alias Core.Repo
  alias Core.WebTracker.Sessions.PaidCampaign

  @err_not_found {:error, "paid campaign not found"}

  def get_by_hash(hash) do
    case Repo.get_by(PaidCampaign, hash: hash) do
      %PaidCampaign{} = campaign -> {:ok, campaign}
      nil -> @err_not_found
    end
  end

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
