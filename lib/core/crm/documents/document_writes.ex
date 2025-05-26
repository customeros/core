defmodule Core.Crm.Documents.DocumentWrite do
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
