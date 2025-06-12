defmodule Core.Crm.Companies.ExternalCompany do
  @moduledoc """
  Schema module for managing external company mappings.

  This schema represents a mapping between a company in an external system
  (e.g., HubSpot) and a company in our system. It stores the relationship
  and any additional data from the external system.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  # Constants
  @id_prefix "ec"
  @id_regex ~r/^#{@id_prefix}_[a-z0-9]{21}$/

  schema "external_companies" do
    field :external_id, :string
    field :company_id, :string
    field :external_data, :map
    field :last_synced_at, :utc_datetime

    timestamps(type: :utc_datetime)

    belongs_to :integration_connection, Core.Integrations.IntegrationConnection,
      foreign_key: :integration_connection_id,
      type: :string
  end

  @type t :: %__MODULE__{
          id: String.t(),
          integration_connection_id: String.t(),
          external_id: String.t(),
          company_id: String.t(),
          external_data: map() | nil,
          last_synced_at: DateTime.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          integration_connection: Core.Integrations.IntegrationConnection.t() | nil
        }

  @doc """
  Returns the ID prefix used for external companies.
  """
  def id_prefix, do: @id_prefix

  @doc """
  Creates a changeset for external company.
  """
  def changeset(external_company, attrs) do
    external_company
    |> cast(attrs, [
      :id,
      :integration_connection_id,
      :external_id,
      :company_id,
      :external_data,
      :last_synced_at
    ])
    |> validate_required([
      :id,
      :integration_connection_id,
      :external_id,
      :company_id,
      :last_synced_at
    ])
    |> validate_format(:id, @id_regex)
    |> unique_constraint([:integration_connection_id, :external_id])
    |> foreign_key_constraint(:integration_connection_id)
  end
end
