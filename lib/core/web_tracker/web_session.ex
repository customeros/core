defmodule Core.WebTracker.WebSession do
  @moduledoc """
  Schema and methods for managing web sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Core.Repo
  alias Core.Utils.IdGenerator

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  schema "web_sessions" do
    field :tenant, :string
    field :visitor_id, :string
    field :origin, :string
    field :active, :boolean, default: true
    field :metadata, :map, default: %{}

    # IP information
    field :ip, :string
    field :city, :string
    field :region, :string
    field :country_code, :string
    field :is_mobile, :boolean

    # Custom timestamps
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :created_at, :utc_datetime
    field :updated_at, :utc_datetime
  end

  @type t :: %__MODULE__{
    id: String.t(),
    tenant: String.t(),
    visitor_id: String.t(),
    origin: String.t(),
    active: boolean(),
    metadata: map(),
    # IP information
    ip: String.t() | nil,
    city: String.t() | nil,
    region: String.t() | nil,
    country_code: String.t() | nil,
    is_mobile: boolean() | nil,
    # Timestamps
    started_at: DateTime.t() | nil,
    ended_at: DateTime.t() | nil,
    created_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @doc """
  Creates a new web session.
  """
  @spec create(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    attrs = attrs
      |> Map.put(:id, IdGenerator.generate_id_21("sess"))
      |> Map.put(:created_at, now)
      |> Map.put(:updated_at, now)
      |> Map.put(:started_at, now)

    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an active session for the given tenant, visitor_id and origin combination.
  Returns nil if no active session is found.
  """
  @spec get_active_session(String.t(), String.t(), String.t()) :: t() | nil
  def get_active_session(tenant, visitor_id, origin) do
    from(s in __MODULE__,
      where: not is_nil(s.tenant) and s.tenant == ^tenant and
             not is_nil(s.visitor_id) and s.visitor_id == ^visitor_id and
             not is_nil(s.origin) and s.origin == ^origin and
             s.active == true
    )
    |> Repo.one()
  end

  @doc """
  Validates the changeset for a web session.
  """
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :id, :tenant, :visitor_id, :origin, :active, :metadata,
      :ip, :city, :region, :country_code, :is_mobile,
      :started_at, :ended_at, :created_at, :updated_at
    ])
    |> validate_required([:id, :tenant, :visitor_id, :origin, :created_at, :updated_at])
    |> validate_format(:id, ~r/^sess_[a-z0-9]{21}$/)
  end
end
