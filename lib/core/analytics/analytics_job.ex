defmodule Core.Analytics.AnalyticsJob do
  @moduledoc """
  Schema module representing analytics jobs.

  This schema stores analytics job records for scheduled data processing:
  - Job types: hourly lead generation aggregation and channel analysis
  - Job status tracking: pending, completed, failed
  - Tenant-specific job scheduling
  - Timestamp tracking for job lifecycle management

  Jobs are used by the analytics system to coordinate data aggregation tasks.
  """

  alias Jason.Encoder.DateTime
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "analytics_jobs" do
    field(:job_type, Ecto.Enum,
      values: [:hourly_lead_generation_agg, :hourly_lead_generation_channel]
    )

    field(:tenant_id, :string)
    field(:scheduled_at, :utc_datetime)

    field(:status, Ecto.Enum,
      values: [:pending, :completed, :failed],
      default: :pending
    )

    timestamps(type: :utc_datetime)
  end

  @required_fields [:job_type, :tenant_id, :scheduled_at]
  @optional_fields [:status]

  @type job_status :: :pending | :completed | :failed
  @type job_type ::
          :hourly_lead_generation_agg | :hourly_lead_generation_channel
  @type t :: %__MODULE__{
          id: binary(),
          job_type: job_type,
          tenant_id: String.t(),
          scheduled_at: DateTime.t(),
          status: job_status,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  def changeset(job \\ %__MODULE__{}, attrs) do
    job
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
