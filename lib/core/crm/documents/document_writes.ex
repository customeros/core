defmodule Core.Crm.Documents.DocumentWrite do
  @moduledoc """
  Schema module for storing document write operations in the CRM system.

  This schema tracks document versions and their binary content, supporting
  different version formats (v1 and v1_sv) for document persistence.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "document_writes" do
    field(:value, :binary)
    field(:version, Ecto.Enum, values: [:v1, :v1_sv])
    field(:document_id, :string)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(yjs_doc, attrs) do
    yjs_doc
    |> cast(attrs, [:document_id, :value, :version])
    |> validate_required([:document_id, :value, :version])
  end
end
