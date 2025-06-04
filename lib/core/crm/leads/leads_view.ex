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
             :icp_fit,
             :industry,
             :domain,
             :icon,
             :country,
             :country_name,
             :document_id
           ]}
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
    :document_id
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
          document_id: String.t() | nil
        }
end
