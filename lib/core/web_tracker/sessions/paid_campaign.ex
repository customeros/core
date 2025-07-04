defmodule Core.WebTracker.Sessions.PaidCampaign do
  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Utils.IdGenerator

  @primary_key {:id, :string, autogenerate: false}
  @id_prefix "paid"
  @ad_platforms [
    :google,
    :bing,
    :linkedin,
    :facebook,
    :x,
    :youtube,
    :instagram,
    :tiktok,
    :other
  ]

  schema "paid_campaigns" do
    field(:platform, Ecto.Enum, values: @ad_platforms)
    field(:campaign_id, :string)
    field(:account_id, :string)
    field(:group_id, :string)
    field(:targeting_id, :string)
    field(:content_id, :string)
    field(:hash, :string)
    field(:first_seen_at, :utc_datetime)
    field(:last_seen_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          campaign_id: String.t() | nil,
          account_id: String.t() | nil,
          group_id: String.t() | nil,
          targeting_id: String.t() | nil,
          content_id: String.t() | nil,
          hash: String.t(),
          first_seen_at: DateTime.t(),
          last_seen_at: DateTime.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @required_fields [
    :hash
  ]
  @optional_fields [
    :campaign_id,
    :account_id,
    :group_id,
    :targeting_id,
    :content_id,
    :first_seen_at,
    :last_seen_at
  ]

  def changeset(%__MODULE__{} = ad, attrs) do
    ad
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> generate_hash()
    |> put_timestamps()
    |> validate_required(@required_fields)
    |> unique_constraint(:hash)
    |> maybe_put_id()
  end

  defp put_timestamps(changeset) do
    now = DateTime.utc_now()

    changeset
    |> put_change(:last_seen_at, now)
    |> maybe_put_first_seen(now)
  end

  defp maybe_put_first_seen(%{data: %{first_seen_at: nil}} = changeset, now) do
    put_change(changeset, :first_seen_at, now)
  end

  defp maybe_put_first_seen(changeset, _now), do: changeset

  defp generate_hash(changeset) do
    case changeset do
      %{valid?: true} ->
        hash_input =
          [
            get_field(changeset, :campaign_id),
            get_field(changeset, :account_id),
            get_field(changeset, :group_id),
            get_field(changeset, :targeting_id),
            get_field(changeset, :content_id)
          ]
          |> Enum.map_join("|", &(&1 || ""))

        hash = :crypto.hash(:sha256, hash_input) |> Base.encode16(case: :lower)
        put_change(changeset, :hash, hash)

      _ ->
        changeset
    end
  end

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(
      changeset,
      :id,
      IdGenerator.generate_id_21(@id_prefix)
    )
  end

  defp maybe_put_id(changeset), do: changeset
end
