defmodule Core.Crm.Contacts.Enricher.BetterContactJob do
  @moduledoc """
  Schema for tracking BetterContact enrichment job status.

  This module defines the database schema for BetterContact enrichment jobs,
  including job status tracking, attempt counting, and scheduling information.
  It provides validation and changeset functions for job lifecycle management.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "better_contact_jobs" do
    field(:job_id, :string)
    field(:contact_id, :string)

    field(:status, Ecto.Enum,
      values: [:processing, :completed, :failed],
      default: :processing
    )

    field(:completed_attempts, :integer, default: 0)
    field(:next_check_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @required_fields [
    :job_id
  ]

  @optional_fields [
    :contact_id,
    :status,
    :completed_attempts,
    :next_check_at
  ]

  @type job_status :: :processing | :completed | :failed
  @type t :: %__MODULE__{
          id: String.t(),
          job_id: String.t(),
          contact_id: String.t() | nil,
          status: job_status,
          completed_attempts: integer() | nil,
          next_check_at: DateTime.t() | nil
        }

  def changeset(%__MODULE__{} = job, attrs) do
    job
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:completed_attempts, greater_than_or_equal_to: 0)
    |> unique_constraint(:job_id)
  end
end
