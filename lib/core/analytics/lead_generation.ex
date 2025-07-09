defmodule Core.Analytics.LeadGeneration do
  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Repo

  schema "analytics_lead_generation" do
    field(:bucket_start_at, :utc_datetime)
    field(:tenant_id, :string)
    field(:sessions, :integer)
    field(:identified_sessions, :integer)
    field(:icp_fit_sessions, :integer)
    field(:unique_companies, :integer)
    field(:new_icp_fit_leads, :integer)
    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          bucket_start_at: DateTime.t(),
          tenant_id: String.t(),
          sessions: Integer.t(),
          identified_sessions: Integer.t(),
          icp_fit_sessions: Integer.t(),
          unique_companies: Integer.t(),
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
      :new_icp_fit_leads
    ])
    |> validate_required([
      :bucket_start_at,
      :tenant_id,
      :sessions,
      :identified_sessions,
      :icp_fit_sessions,
      :unique_companies,
      :new_icp_fit_leads
    ])
    |> validate_number(:sessions, greater_than_or_equal_to: 0)
    |> validate_number(:identified_sessions, greater_than_or_equal_to: 0)
    |> validate_number(:icp_fit_sessions, greater_than_or_equal_to: 0)
    |> validate_number(:unique_companies, greater_than_or_equal_to: 0)
    |> validate_number(:new_icp_fit_leads, greater_than_or_equal_to: 0)
    |> unique_constraint([:tenant_id, :bucket_start_at])
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
           :new_icp_fit_leads,
           :updated_at
         ]},
      conflict_target: [:tenant_id, :bucket_start_at]
    )
  end
end
