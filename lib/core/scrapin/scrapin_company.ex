defmodule Core.ScrapinCompany do
  @moduledoc """
  Schema module representing a ScrapIn company enrichment record.

  This schema stores enrichment results and metadata for companies fetched via ScrapIn integration.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @id_prefix "scrapin"
  @id_regex ~r/^#{@id_prefix}_[a-z0-9]{21}$/

  schema "scrapin_companies" do
    field :linkedin_id, :string
    field :linkedin_alias, :string
    field :domain, :string
    field :request_param, :string
    field :data, :string
    field :success, :boolean, default: false
    field :company_found, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          linkedin_id: String.t() | nil,
          linkedin_alias: String.t() | nil,
          domain: String.t() | nil,
          request_param: String.t(),
          data: String.t() | nil,
          success: boolean(),
          company_found: boolean(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  def id_prefix, do: @id_prefix

  def changeset(scrapin_company, attrs) do
    scrapin_company
    |> cast(attrs, [
      :id,
      :linkedin_id,
      :linkedin_alias,
      :domain,
      :request_param,
      :data,
      :success,
      :company_found
    ])
    |> validate_required([:id, :request_param])
    |> validate_format(:id, @id_regex)
    |> unique_constraint(:id)
  end
end
