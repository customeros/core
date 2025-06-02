defmodule Core.Researcher.IcpProfiles.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          domain: String.t(),
          tenant_id: String.t() | nil,
          profile: String.t(),
          qualifying_attributes: [String.t()],
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "ideal_customer_profiles" do
    field(:domain, :string)
    field(:tenant_id, :string)
    field(:profile, :string)
    field(:qualifying_attributes, {:array, :string}, default: [])

    timestamps()
  end

  @required_fields [:domain, :profile]
  @optional_fields [:tenant_id, :qualifying_attributes]

  def changeset(ideal_customer_profile, attrs) do
    ideal_customer_profile
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:domain, min: 1, max: 255)
    |> validate_length(:profile, min: 1, max: 1200)
    |> validate_length(:tenant_id, min: 1, max: 100)
    |> unique_constraint(:domain)
  end
end
