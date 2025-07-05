defmodule Core.Crm.TargetPersonas.TargetPersonaLinkedinQueue do
  @moduledoc """
  Schema for tracking LinkedIn profile processing queue items.

  This module defines the database schema for queued LinkedIn profiles that
  need to be processed for target persona creation. It tracks processing
  attempts, completion status, and timing information for each queued item.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "target_persona_linkedin_queues" do
    field(:tenant_id, :string)
    field(:linkedin_url, :string)
    field(:completed_at, :utc_datetime)
    field(:last_attempt_at, :utc_datetime)
    field(:attempts, :integer, default: 0)
    field(:inserted_at, :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          tenant_id: String.t(),
          linkedin_url: String.t(),
          completed_at: DateTime.t(),
          last_attempt_at: DateTime.t(),
          attempts: integer(),
          inserted_at: DateTime.t()
        }

  @required_fields [
    :tenant_id,
    :linkedin_url
  ]

  @doc false
  def changeset(target_persona_linkedin_queue, attrs) do
    target_persona_linkedin_queue
    |> cast(attrs, [
      :tenant_id,
      :linkedin_url,
      :completed_at,
      :last_attempt_at,
      :attempts
    ])
    |> validate_required(@required_fields)
    |> validate_number(:attempts, greater_than_or_equal_to: 0)
  end
end
