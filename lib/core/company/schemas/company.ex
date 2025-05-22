defmodule Core.Company.Schemas.Company do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @id_prefix "cmp"
  @id_regex ~r/^#{@id_prefix}_[a-z0-9]{21}$/

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
    field(:icon_enrich_attempt_at, :utc_datetime)

    # LinkedIn fields
    field(:linkedin_id, :string)
    field(:linkedin_alias, :string)

    # Scraped content
    # home page
    field(:homepage_content, :string)

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
          icon_enrich_attempt_at: DateTime.t() | nil,
          # LinkedIn fields
          linkedin_id: String.t() | nil,
          linkedin_alias: String.t() | nil,
          # Scraped content
          homepage_content: String.t() | nil,
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
      :icon_enrich_attempt_at,
      :linkedin_id,
      :linkedin_alias,
      :homepage_content
    ])
    |> validate_required([:id, :primary_domain])
    |> validate_format(:id, @id_regex)
    |> unique_constraint(:primary_domain)
  end
end
