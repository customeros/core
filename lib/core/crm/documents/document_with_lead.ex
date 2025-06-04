defmodule Core.Crm.Documents.DocumentWithLead do
  @moduledoc """
  Struct for documents joined with lead references
  """

  defstruct [:document_id, :document_name, :body, :tenant_id, :lead_id]

  @type t :: %__MODULE__{
          document_id: String.t(),
          document_name: String.t(),
          body: String.t(),
          tenant_id: String.t(),
          lead_id: String.t()
        }
end
