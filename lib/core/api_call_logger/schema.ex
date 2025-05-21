defmodule Core.ApiCallLogger.Schema do
  @moduledoc """
  Schema for logging API calls to external services.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  # Constants
  @id_prefix "api"
  @id_regex ~r/^#{@id_prefix}_[a-z0-9]{21}$/

  schema "api_call_logs" do
    field :vendor, :string
    field :method, :string
    field :url, :string
    field :request_body, :binary
    field :duration, :integer
    field :status_code, :integer
    field :response_body, :binary
    field :error_message, :string

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
    id: String.t(),
    vendor: String.t(),
    method: String.t(),
    url: String.t(),
    request_body: binary() | nil,
    duration: integer(),
    status_code: integer() | nil,
    response_body: binary() | nil,
    error_message: String.t() | nil,
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @doc """
  Returns the ID prefix used for API call logs.
  """
  def id_prefix, do: @id_prefix

  @doc """
  Validates the changeset for an API call log.
  """
  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :id, :vendor, :method, :url, :request_body,
      :duration, :status_code, :response_body, :error_message
    ])
    |> validate_required([:id, :vendor, :method, :url, :duration])
    |> validate_format(:id, @id_regex)
  end
end
