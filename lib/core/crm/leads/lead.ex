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
  @type icp_fit :: :strong | :moderate | :not_a_fit | :unknown
  @type disqualification_reason ::
          :company_too_small
          | :company_too_large
          | :company_declining
          | :competitor
          | :incompatible_tech_stack
          | :legacy_system_constraints
          | :market_position_mismatch
          | :no_use_case
          | :regulatory_restrictions
          | :revenue_model_mismatch
          | :startup_too_early
          | :unable_to_determine_fit
          | :no_business_pages_found
          | :user_feedback
          | :wrong_industry
          | :wrong_geography
          | :wrong_business_model

  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t(),
          ref_id: String.t(),
          type: lead_type,
          stage: lead_stage,
          icp_fit: icp_fit,
          icp_disqualification_reason: [disqualification_reason],
          error_message: String.t(),
          icp_fit_evaluation_attempt_at: DateTime.t(),
          icp_fit_evaluation_attempts: integer(),
          brief_create_attempt_at: DateTime.t(),
          brief_create_attempts: integer(),
          just_created: boolean(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :string, autogenerate: false}
  schema "leads" do
    field(:tenant_id, :string)
    field(:ref_id, :string)
    field(:type, Ecto.Enum, values: [:contact, :company])

    field(:icp_fit, Ecto.Enum,
      values: [:strong, :moderate, :not_a_fit, :unknown],
      default: :unknown
    )

    field(:stage, Ecto.Enum,
      values: [
        :pending,
        :target,
        :education,
        :solution,
        :evaluation,
        :ready_to_buy,
        :customer
      ],
      default: :pending
    )

    field(:icp_disqualification_reason, {:array, Ecto.Enum},
      values: [
        :company_too_small,
        :company_too_large,
        :company_declining,
        :competitor,
        :incompatible_tech_stack,
        :legacy_system_constraints,
        :market_position_mismatch,
        :no_use_case,
        :regulatory_restrictions,
        :revenue_model_mismatch,
        :startup_too_early,
        :unable_to_determine_fit,
        :no_business_pages_found,
        :user_feedback,
        :wrong_industry,
        :wrong_geography,
        :wrong_business_model
      ]
    )

    field(:error_message, :string)
    field(:icp_fit_evaluation_attempt_at, :utc_datetime)
    field(:icp_fit_evaluation_attempts, :integer, default: 0)
    field(:brief_create_attempt_at, :utc_datetime)
    field(:brief_create_attempts, :integer, default: 0)

    field(:just_created, :boolean, virtual: true, default: false)

    timestamps(type: :utc_datetime)
  end

  @required_fields [
    :tenant_id
  ]

  @optional_fields [
    :id,
    :stage,
    :ref_id,
    :type,
    :icp_fit,
    :error_message,
    :icp_fit_evaluation_attempt_at,
    :icp_fit_evaluation_attempts,
    :brief_create_attempt_at,
    :brief_create_attempts,
    :just_created,
    :icp_disqualification_reason
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
