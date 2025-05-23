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
    :industry
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          ref_id: String.t(),
          type: Core.Crm.Leads.Lead.lead_type(),
          stage: Core.Crm.Leads.Lead.lead_stage(),
          name: String.t() | nil,
          industry: String.t() | nil
        }
end
