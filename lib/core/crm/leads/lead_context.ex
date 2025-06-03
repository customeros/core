defmodule Core.Crm.Leads.LeadContext do
  @moduledoc """
  Struct representing the context for lead operations.

  This module defines a struct that holds the necessary context for performing
  lead-related operations, including tenant and lead identification, as well as
  associated company data.
  """

  defstruct [:tenant_id, :lead_id, :lead, :company]
end
