defmodule Core.Crm.Leads.LeadView do
  @moduledoc """
  Struct representing a lead view entry with associated company info.
  """
  @derive {Jason.Encoder,
           only: [
             :id,
             :ref_id,
             :type,
             :stage,
             :name,
             :industry,
             :domain,
             :logo,
             :country,
             :country_name
           ]}
  defstruct [
    :id,
    :ref_id,
    :type,
    :stage,
    :name,
    :industry,
    :domain,
    :logo,
    :country,
    :country_name
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          ref_id: String.t(),
          type: Core.Crm.Leads.Lead.lead_type(),
          stage: Core.Crm.Leads.Lead.lead_stage(),
          name: String.t() | nil,
          industry: String.t() | nil,
          domain: String.t() | nil,
          logo: String.t() | nil,
          country: String.t() | nil,
          country_name: String.t() | nil
        }
end
