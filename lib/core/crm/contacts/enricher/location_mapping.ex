defmodule Core.Crm.Contacts.Enricher.LocationMapping do
  use Ecto.Schema
  import Ecto.Changeset

  schema "location_mapping" do
    field(:location, :string)
    field(:country_a2, :string)
    field(:region, :string)
    field(:city, :string)
    field(:timezone, :string)

    timestamps()
  end

  @doc false
  def changeset(location_mapping, attrs) do
    location_mapping
    |> cast(attrs, [:location, :country_a2, :region, :city, :timezone])
    |> validate_required([:location])
  end
end
