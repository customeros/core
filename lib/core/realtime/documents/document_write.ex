defmodule Core.Realtime.Documents.DocumentWrite do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "document_writes" do
    field :docName, :string
    field :value, :string
    field :version, :string

    timestamps()
  end

  @doc false
  def changeset(document_write, attrs) do
    document_write
    |> cast(attrs, [:docName, :value, :version])
    |> validate_required([:docName, :value, :version])
  end
end
