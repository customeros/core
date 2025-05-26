defmodule Core.Crm.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :body,
             :lexical_state,
             :tenant_id,
             :user_id,
             :icon,
             :color,
             :ref_id,
             :inserted_at,
             :updated_at
           ]}
  @primary_key {:id, :string, autogenerate: false}
  schema "documents" do
    field(:name, :string)
    field(:body, :string)
    field(:lexical_state, :string)
    field(:tenant_id, :string)
    field(:user_id, :string)
    field(:icon, :string)
    field(:color, :string)
    field(:ref_id, :string, virtual: true)

    timestamps(type: :utc_datetime)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :name,
      :body,
      :lexical_state,
      :tenant_id,
      :user_id,
      :icon,
      :color
    ])
    |> maybe_put_id()
    |> validate_required([:name, :tenant_id, :body, :user_id, :icon, :color])
  end

  def update_changeset(document, attrs) do
    document
    |> cast(attrs, [:id, :name, :icon, :color])
    |> validate_required([:id, :name, :icon, :color])
  end

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(
      changeset,
      :id,
      Core.Utils.IdGenerator.generate_id_21("doc")
    )
  end

  defp maybe_put_id(changeset), do: changeset
end
