defmodule Core.Crm.Leads.Lead do
  use Ecto.Schema
  import Ecto.Changeset

  @type lead_type :: :contact | :company
  @type lead_stage ::
          :target | :education | :solution | :evaluation | :ready_to_buy
  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t(),
          ref_id: String.t(),
          type: lead_type,
          stage: lead_stage,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :string, autogenerate: false}
  schema "leads" do
    field(:tenant_id, :string)
    field(:ref_id, :string)
    field(:type, Ecto.Enum, values: [:contact, :company])

    field(:stage, Ecto.Enum,
      values: [:target, :education, :solution, :evaluation, :ready_to_buy],
      default: :target
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = lead, attrs) do
    lead
    |> cast(attrs, [:id, :tenant_id, :ref_id, :type, :stage])
    |> maybe_put_id()
    |> validate_required([:tenant_id, :ref_id, :type])
  end

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Core.Utils.IdGenerator.generate_id_21("lead"))
  end

  defp maybe_put_id(changeset), do: changeset
end
