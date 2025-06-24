defmodule Core.Crm.Leads.Lead do
  @moduledoc """
  Defines and manages the Lead data structure and lifecycle in the CRM system.

  This module handles the representation and management of leads, including:
  - Lead data structure and validation
  - Lead lifecycle stages (from pending to customer)
  - ICP fit assessment
  - Lead creation and event broadcasting
  - Integration with the new lead pipeline
  """

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
  @type icp_fit :: :strong | :moderate | :not_a_fit
  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t(),
          ref_id: String.t(),
          type: lead_type,
          stage: lead_stage,
          icp_fit: icp_fit,
          error_message: String.t(),
          icp_fit_evaluation_attempt_at: DateTime.t(),
          icp_fit_evaluation_attempts: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :string, autogenerate: false}
  schema "leads" do
    field(:tenant_id, :string)
    field(:ref_id, :string)
    field(:type, Ecto.Enum, values: [:contact, :company])
    field(:icp_fit, Ecto.Enum, values: [:strong, :moderate, :not_a_fit])

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
    field(:icp_fit_evaluation_attempt_at, :utc_datetime)
    field(:icp_fit_evaluation_attempts, :integer, default: 0)

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
    :error_message,
    :icp_fit_evaluation_attempt_at,
    :icp_fit_evaluation_attempts
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
end
