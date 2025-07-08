defmodule Core.Crm.Leads.LeadView do
  @moduledoc """
  Struct representing a lead view entry with associated company info.
  """

  defstruct [
    :id,
    :ref_id,
    :type,
    :stage,
    :name,
    :icp_fit,
    :industry,
    :domain,
    :icon,
    :country,
    :country_name,
    :document_id,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          ref_id: String.t(),
          type: Core.Crm.Leads.Lead.lead_type(),
          stage: Core.Crm.Leads.Lead.lead_stage(),
          name: String.t() | nil,
          icp_fit: Core.Crm.Leads.Lead.icp_fit(),
          industry: String.t() | nil,
          domain: String.t() | nil,
          icon: String.t() | nil,
          country: String.t() | nil,
          country_name: String.t() | nil,
          document_id: String.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defimpl Jason.Encoder, for: __MODULE__ do
    def encode(lead_view, opts) do
      lead_view
      |> Map.take([
        :id,
        :ref_id,
        :type,
        :stage,
        :name,
        :icp_fit,
        :industry,
        :domain,
        :icon,
        :country,
        :country_name,
        :document_id,
        :inserted_at,
        :updated_at
      ])
      |> Jason.Encode.map(opts)
    end
  end
end
