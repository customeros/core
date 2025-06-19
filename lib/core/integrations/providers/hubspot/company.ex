defmodule Core.Integrations.Providers.HubSpot.HubSpotCompany do
  @moduledoc "Struct for a HubSpot company object"

  defstruct [
    :id,
    :archived,
    :created_at,
    :updated_at,
    :name,
    :domain,
    :hs_object_id,
    :createdate,
    :hs_lastmodifieddate,
    :type,
    :raw_properties
  ]

  @doc """
  Maps a raw HubSpot company map to a HubSpotCompany struct.
  """
  def from_hubspot_map(%{
        "id" => id,
        "archived" => archived,
        "createdAt" => created_at,
        "updatedAt" => updated_at,
        "properties" => props
      }) do
    %__MODULE__{
      id: id,
      archived: archived,
      created_at: created_at,
      updated_at: updated_at,
      name: Map.get(props, "name"),
      domain: Map.get(props, "domain"),
      hs_object_id: Map.get(props, "hs_object_id"),
      createdate: Map.get(props, "createdate"),
      hs_lastmodifieddate: Map.get(props, "hs_lastmodifieddate"),
      type: Map.get(props, "type"),
      raw_properties: props
    }
  end
end
