defmodule Core.Crm.Documents.RefDocument do
  @moduledoc """
  Schema module for managing document references in the CRM system.

  This schema represents the relationship between references and documents,
  storing the mapping between ref_id and document_id.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "refs_documents" do
    field(:ref_id, :string)
    field(:document_id, :string)
  end

  def changeset(ref_document, attrs) do
    ref_document
    |> cast(attrs, [:ref_id, :document_id])
    |> validate_required([:ref_id, :document_id])
  end
end
