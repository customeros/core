defmodule Core.WebTracker.Sessions.UtmCampaign do
  @moduledoc """
  Schema for tracking UTM campaign parameters from web traffic.

  This module handles the storage and validation of UTM parameters
  (utm_source, utm_medium, utm_campaign, utm_term, utm_content) used
  for tracking marketing campaign effectiveness. It generates a unique
  hash based on the UTM parameters and tracks when campaigns are first
  and last seen.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Utils.IdGenerator

  @primary_key {:id, :string, autogenerate: false}
  @id_prefix "utm"

  schema "utm_campaigns" do
    field(:utm_source, :string)
    field(:utm_medium, :string)
    field(:utm_campaign, :string)
    field(:utm_term, :string)
    field(:utm_content, :string)
    field(:utm_hash, :string)
    field(:first_seen_at, :utc_datetime)
    field(:last_seen_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          utm_source: String.t() | nil,
          utm_medium: String.t() | nil,
          utm_campaign: String.t() | nil,
          utm_term: String.t() | nil,
          utm_content: String.t() | nil,
          utm_hash: String.t(),
          first_seen_at: DateTime.t(),
          last_seen_at: DateTime.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @required_fields [
    :utm_hash
  ]
  @optional_fields [
    :utm_source,
    :utm_medium,
    :utm_campaign,
    :utm_term,
    :utm_content,
    :first_seen_at,
    :last_seen_at
  ]

  def changeset(%__MODULE__{} = utm, attrs) do
    utm
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_has_utm_data()
    |> generate_utm_hash()
    |> put_timestamps()
    |> validate_required(@required_fields)
    |> unique_constraint(:utm_hash)
    |> maybe_put_id()
  end

  defp validate_has_utm_data(changeset) do
    utm_fields = [
      :utm_source,
      :utm_medium,
      :utm_campaign,
      :utm_term,
      :utm_content
    ]

    has_utm_data =
      Enum.any?(utm_fields, fn field ->
        case get_field(changeset, field) do
          nil -> false
          "" -> false
          _value -> true
        end
      end)

    if has_utm_data do
      changeset
    else
      add_error(changeset, :base, "At least one UTM parameter must be present")
    end
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

  defp generate_utm_hash(changeset) do
    case changeset do
      %{valid?: true} ->
        hash_input =
          [
            get_field(changeset, :utm_source),
            get_field(changeset, :utm_medium),
            get_field(changeset, :utm_campaign),
            get_field(changeset, :utm_term),
            get_field(changeset, :utm_content)
          ]
          |> Enum.map_join("|", &(&1 || ""))

        hash = :crypto.hash(:sha256, hash_input) |> Base.encode16(case: :lower)
        put_change(changeset, :utm_hash, hash)

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
