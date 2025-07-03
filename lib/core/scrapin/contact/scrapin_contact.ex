defmodule Core.ScrapinContact do
  @moduledoc """
  Schema module representing a ScrapIn contact enrichment record.

  This schema stores enrichment results and metadata for contacts fetched via ScrapIn integration.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @id_prefix "scrapin"
  @id_regex ~r/^#{@id_prefix}_[a-z0-9]{21}$/

  schema "scrapin_contacts" do
    field(:linkedin_id, :string)
    field(:linkedin_alias, :string)
    field(:request_param_linkedin, :string)
    field(:request_param_first_name, :string)
    field(:request_param_last_name, :string)
    field(:request_param_email, :string)
    field(:request_param_company_domain, :string)
    field(:request_param_company_name, :string)
    field(:data, :string)
    field(:success, :boolean, default: false)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          linkedin_id: String.t() | nil,
          linkedin_alias: String.t() | nil,
          request_param_linkedin: String.t() | nil,
          request_param_first_name: String.t() | nil,
          request_param_last_name: String.t() | nil,
          request_param_email: String.t() | nil,
          request_param_company_domain: String.t() | nil,
          request_param_company_name: String.t() | nil,
          data: String.t() | nil,
          success: boolean(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  def id_prefix, do: @id_prefix

  def changeset(scrapin_contact, attrs) do
    scrapin_contact
    |> cast(attrs, [
      :id,
      :linkedin_id,
      :linkedin_alias,
      :request_param_linkedin,
      :request_param_first_name,
      :request_param_last_name,
      :request_param_email,
      :request_param_company_domain,
      :request_param_company_name,
      :data,
      :success
    ])
    |> validate_required([:id])
    |> validate_format(:id, @id_regex)
    |> unique_constraint(:id)
  end
end
