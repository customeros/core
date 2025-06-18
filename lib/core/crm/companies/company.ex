defmodule Core.Crm.Companies.Company do
  @moduledoc """
  Schema module representing a company in the CRM system.

  This schema stores comprehensive company information including:
  - Basic company details (name, domain, industry)
  - Enrichment status and attempts for various data points
  - LinkedIn integration data
  - Scraped website content
  - Country and icon information

  Companies are identified by a unique ID with a 'cmp_' prefix.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @id_prefix "cmp"
  @id_regex ~r/^#{@id_prefix}_[a-z0-9]{21}$/

  @type business_model :: :B2B | :B2C | :B2B2C | :Hybrid

  schema "companies" do
    # Required fields
    field(:primary_domain, :string)
    field(:name, :string)
    field(:industry_code, :string)
    field(:industry, :string)
    field(:icon_key, :string)
    field(:country_a2, :string)

    # Enrichment attempt timestamps
    field(:domain_scrape_attempt_at, :utc_datetime)
    field(:industry_enrich_attempt_at, :utc_datetime)
    field(:name_enrich_attempt_at, :utc_datetime)
    field(:country_enrich_attempt_at, :utc_datetime)
    field(:icon_enrich_attempt_at, :utc_datetime)
    field(:business_model_enrich_attempt_at, :utc_datetime)

    # Enrichment attempt counters
    field(:domain_scrape_attempts, :integer, default: 0)
    field(:industry_enrichment_attempts, :integer, default: 0)
    field(:name_enrichment_attempts, :integer, default: 0)
    field(:country_enrichment_attempts, :integer, default: 0)
    field(:icon_enrichment_attempts, :integer, default: 0)
    field(:business_model_enrichment_attempts, :integer, default: 0)

    # LinkedIn fields
    field(:linkedin_id, :string)
    field(:linkedin_alias, :string)

    # Scraped content
    # home page
    field(:homepage_content, :string)
    field(:homepage_scraped, :boolean, default: false)

    # Quantitative fields
    field(:technologies_used, {:array, :string}, default: [])
    field(:city, :string)
    field(:region, :string)
    field(:business_model, Ecto.Enum, values: [:B2B, :B2C, :B2B2C, :Hybrid])
    field(:employee_count, :integer)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          primary_domain: String.t(),
          name: String.t() | nil,
          industry_code: String.t() | nil,
          industry: String.t() | nil,
          icon_key: String.t() | nil,
          country_a2: String.t() | nil,
          # Enrichment attempt timestamps
          domain_scrape_attempt_at: DateTime.t() | nil,
          industry_enrich_attempt_at: DateTime.t() | nil,
          name_enrich_attempt_at: DateTime.t() | nil,
          country_enrich_attempt_at: DateTime.t() | nil,
          icon_enrich_attempt_at: DateTime.t() | nil,
          business_model_enrich_attempt_at: DateTime.t() | nil,
          # Enrichment attempt counters
          domain_scrape_attempts: integer(),
          industry_enrichment_attempts: integer(),
          name_enrichment_attempts: integer(),
          country_enrichment_attempts: integer(),
          icon_enrichment_attempts: integer(),
          business_model_enrichment_attempts: integer(),
          # LinkedIn fields
          linkedin_id: String.t() | nil,
          linkedin_alias: String.t() | nil,
          # Scraped content
          homepage_content: String.t() | nil,
          homepage_scraped: boolean(),
          # Quantitative fields
          technologies_used: {:array, :string},
          city: String.t() | nil,
          region: String.t() | nil,
          business_model: Company.business_model(),
          employee_count: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  def id_prefix, do: @id_prefix

  def changeset(company, attrs) do
    company
    |> cast(attrs, [
      :id,
      :primary_domain,
      :name,
      :industry_code,
      :industry,
      :icon_key,
      :country_a2,
      :domain_scrape_attempt_at,
      :industry_enrich_attempt_at,
      :name_enrich_attempt_at,
      :country_enrich_attempt_at,
      :icon_enrich_attempt_at,
      :business_model_enrich_attempt_at,
      :domain_scrape_attempts,
      :industry_enrichment_attempts,
      :name_enrichment_attempts,
      :country_enrichment_attempts,
      :icon_enrichment_attempts,
      :business_model_enrichment_attempts,
      :linkedin_id,
      :linkedin_alias,
      :homepage_content,
      :homepage_scraped,
      :technologies_used,
      :city,
      :region,
      :business_model,
      :employee_count
    ])
    |> validate_required([:id, :primary_domain])
    |> validate_format(:id, @id_regex)
    |> unique_constraint(:primary_domain)
  end
end
