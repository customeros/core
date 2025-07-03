defmodule Core.Crm.Contacts.Contact do
  @moduledoc """
  Schema module representing a contact.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Utils.IdGenerator

  @id_prefix "con"
  @primary_key {:id, :string, autogenerate: false}

  schema "contacts" do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:full_name, :string)
    field(:linkedin_id, :string)
    field(:linkedin_alias, :string)
    field(:linkedin_company_id, :string)
    field(:business_email, :string)
    field(:business_email_status, :string)
    field(:personal_email, :string)
    field(:personal_email_status, :string)
    field(:mobile_phone, :string)
    field(:city, :string)
    field(:region, :string)
    field(:country_a2, :string)
    field(:avatar_key, :string)
    field(:job_title, :string)
    field(:company_id, :string)
    field(:company_domain, :string)
    field(:job_description, :string)
    field(:location, :string)
    field(:headline, :string)
    field(:summary, :string)
    field(:job_started_at, :utc_datetime)
    field(:job_ended_at, :utc_datetime)
    field(:seniority, :string)
    field(:department, :string)

    timestamps(type: :utc_datetime)
  end

  @optional_fields [
    :id,
    :first_name,
    :last_name,
    :full_name,
    :linkedin_id,
    :linkedin_alias,
    :linkedin_company_id,
    :business_email,
    :business_email_status,
    :personal_email,
    :personal_email_status,
    :mobile_phone,
    :city,
    :region,
    :country_a2,
    :avatar_key,
    :job_title,
    :company_id,
    :company_domain,
    :job_description,
    :location,
    :headline,
    :summary,
    :job_started_at,
    :job_ended_at,
    :seniority,
    :department
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          full_name: String.t() | nil,
          linkedin_id: String.t() | nil,
          linkedin_alias: String.t() | nil,
          linkedin_company_id: String.t() | nil,
          business_email: String.t() | nil,
          business_email_status: String.t() | nil,
          personal_email: String.t() | nil,
          personal_email_status: String.t() | nil,
          mobile_phone: String.t() | nil,
          city: String.t() | nil,
          region: String.t() | nil,
          country_a2: String.t() | nil,
          avatar_key: String.t() | nil,
          job_title: String.t() | nil,
          company_id: String.t() | nil,
          company_domain: String.t() | nil,
          job_description: String.t() | nil,
          location: String.t() | nil,
          headline: String.t() | nil,
          summary: String.t() | nil,
          job_started_at: DateTime.t() | nil,
          job_ended_at: DateTime.t() | nil,
          seniority: String.t() | nil,
          department: String.t() | nil
        }

  def changeset(%__MODULE__{} = contact, attrs) do
    contact
    |> cast(attrs, @optional_fields)
    |> maybe_put_id()
  end

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(
      changeset,
      :id,
      IdGenerator.generate_id_21(@id_prefix)
    )
  end

  defp maybe_put_id(changeset), do: changeset
end
