defmodule Core.Realtime.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "documents" do
    field :name, :string
    field :body, :string
    field :tenant, :string
    field :user_id, :binary_id
    field :icon, :string
    field :color, :string
    field :organization_id, :binary_id

    timestamps()
  end

  @doc false
  def changeset(document, attrs) do
    document
    |> cast(attrs, [:name, :body, :tenant, :user_id, :icon, :color, :organization_id])
    |> validate_required([:name, :body, :tenant, :user_id, :organization_id])
  end
end
