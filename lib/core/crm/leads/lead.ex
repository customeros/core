defmodule Core.Crm.Leads.Lead do
  use Ecto.Schema
  import Ecto.Changeset

  @type lead_type :: :contact | :company
  @type lead_stage ::
          :pending
          | :target
          | :education
          | :solution
          | :evaluation
          | :ready_to_buy
          | :customer
          | :not_a_fit
  @type icp_fit :: :strong | :moderate
  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t(),
          ref_id: String.t(),
          type: lead_type,
          stage: lead_stage,
          icp_fit: icp_fit,
          error_message: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :string, autogenerate: false}
  schema "leads" do
    field(:tenant_id, :string)
    field(:ref_id, :string)
    field(:type, Ecto.Enum, values: [:contact, :company])
    field(:icp_fit, Ecto.Enum, values: [:strong, :moderate])

    field(:stage, Ecto.Enum,
      values: [
        :pending,
        :target,
        :education,
        :solution,
        :evaluation,
        :ready_to_buy,
        :not_a_fit,
        :customer
      ],
      default: :pending
    )

    field(:error_message, :string)

    timestamps(type: :utc_datetime)
  end

  @required_fields [
    :tenant_id,
    :ref_id,
    :type
  ]

  @optional_fields [
    :id,
    :stage,
    :icp_fit,
    :error_message
  ]

  def changeset(%__MODULE__{} = lead, attrs) do
    lead
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> maybe_put_id()
  end

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Core.Utils.IdGenerator.generate_id_21("lead"))
  end

  defp maybe_put_id(changeset), do: changeset

  def after_insert(changeset, _opts) do
    lead = changeset.data

    try do
      # Note: Core.Auth.Tenants
      case Core.Auth.Tenants.get_tenant_by_id(lead.tenant_id) do
        {:ok, tenant} ->
          icon_url =
            case Core.Crm.Companies.get_icon_url(lead.ref_id) do
              {:ok, icon_url} -> icon_url
              _ -> nil
            end

          Web.Endpoint.broadcast("events:#{tenant.id}", "event", %{
            type: :lead_created,
            payload: %{
              id: lead.id,
              icon_url: icon_url
            }
          })

          Core.Researcher.NewLeadPipeline.start(lead.id, lead.tenant_id)

        {:error, _} ->
          require Logger

          Logger.warning(
            "Failed to broadcast lead_created event for lead #{lead.id} - tenant not found"
          )
      end
    rescue
      error ->
        require Logger

        Logger.error(
          "Error in after_insert callback for lead #{lead.id}: #{inspect(error)}"
        )
    end

    # Always return the changeset
    changeset
  end
end
