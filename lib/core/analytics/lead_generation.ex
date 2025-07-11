defmodule Core.Analytics.LeadGeneration do
  @moduledoc """
  Schema module representing lead generation analytics data.

  This schema stores aggregated analytics data for lead generation metrics including:
  - Session counts (total, identified, ICP fit)
  - Company counts (unique, new)
  - Lead generation metrics
  - Time-bucketed data for trend analysis

  Data is organized by tenant and time buckets for efficient querying and reporting.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "analytics_lead_generation" do
    field(:bucket_start_at, :utc_datetime)
    field(:tenant_id, :string)
    field(:sessions, :integer)
    field(:identified_sessions, :integer)
    field(:icp_fit_sessions, :integer)
    field(:unique_companies, :integer)
    field(:unique_new_companies, :integer)
    field(:new_icp_fit_leads, :integer)
    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: binary(),
          bucket_start_at: DateTime.t(),
          tenant_id: String.t(),
          sessions: Integer.t(),
          identified_sessions: Integer.t(),
          icp_fit_sessions: Integer.t(),
          unique_companies: Integer.t(),
          unique_new_companies: Integer.t(),
          new_icp_fit_leads: Integer.t()
        }

  def changeset(stats \\ %__MODULE__{}, attrs) do
    stats
    |> cast(attrs, [
      :bucket_start_at,
      :tenant_id,
      :sessions,
      :identified_sessions,
      :icp_fit_sessions,
      :unique_companies,
      :unique_new_companies,
      :new_icp_fit_leads
    ])
    |> validate_required([
      :bucket_start_at,
      :tenant_id,
      :sessions,
      :identified_sessions,
      :icp_fit_sessions,
      :unique_companies,
      :unique_new_companies,
      :new_icp_fit_leads
    ])
    |> validate_number(:sessions, greater_than_or_equal_to: 0)
    |> validate_number(:identified_sessions, greater_than_or_equal_to: 0)
    |> validate_number(:icp_fit_sessions, greater_than_or_equal_to: 0)
    |> validate_number(:unique_companies, greater_than_or_equal_to: 0)
    |> validate_number(:unique_new_companies, greater_than_or_equal_to: 0)
    |> validate_number(:new_icp_fit_leads, greater_than_or_equal_to: 0)
    |> validate_sessions_flow()
    |> unique_constraint([:tenant_id, :bucket_start_at])
  end

  defp validate_sessions_flow(changeset) do
    sessions = get_field(changeset, :sessions) || 0
    identified_sessions = get_field(changeset, :identified_sessions) || 0
    icp_fit_sessions = get_field(changeset, :icp_fit_sessions) || 0
    unique_new_companies = get_field(changeset, :unique_new_companies) || 0
    new_icp_fit_leads = get_field(changeset, :new_icp_fit_leads) || 0

    changeset
    |> validate_field_relationship(
      :identified_sessions,
      :sessions,
      identified_sessions,
      sessions
    )
    |> validate_field_relationship(
      :icp_fit_sessions,
      :identified_sessions,
      icp_fit_sessions,
      identified_sessions
    )
    |> validate_field_relationship(
      :new_icp_fit_leads,
      :unique_new_companies,
      new_icp_fit_leads,
      unique_new_companies
    )
  end

  defp validate_field_relationship(changeset, field1, field2, value1, value2) do
    if value1 > value2 do
      add_error(changeset, field1, "cannot be greater than #{field2}")
    else
      changeset
    end
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def upsert(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace,
         [
           :sessions,
           :identified_sessions,
           :icp_fit_sessions,
           :unique_companies,
           :unique_new_companies,
           :new_icp_fit_leads,
           :updated_at
         ]},
      conflict_target: [:tenant_id, :bucket_start_at]
    )
  end
end
