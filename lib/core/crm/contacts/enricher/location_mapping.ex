defmodule Core.Crm.Contacts.Enricher.LocationMapping do
  @moduledoc """
  Schema and changeset for mapping location strings to structured geographic data.

  This module handles the persistence and validation of location data mappings, including:
  - Raw location string to structured location components
  - Country codes (A2 format)
  - Regional information
  - City names
  - Timezone data

  Used by the contact enrichment system to standardize and structure location information.
  """

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
