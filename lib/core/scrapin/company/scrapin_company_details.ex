defmodule Core.ScrapinCompanyDetails do
  @moduledoc """
  Struct for company details returned by ScrapIn API.
  Matches the JSON response structure for company enrichment.
  """
  @derive Jason.Encoder

  @type employee_count_range :: %{
          optional(:start) => integer(),
          optional(:end) => integer()
        }

  @type headquarter :: %{
          optional(:city) => String.t() | nil,
          optional(:country) => String.t() | nil,
          optional(:postal_code) => String.t() | nil,
          optional(:geographic_area) => String.t() | nil,
          optional(:street1) => String.t() | nil,
          optional(:street2) => String.t() | nil
        }

  @type founded_on :: %{
          optional(:year) => integer()
        }

  @type funding_data :: map()

  @type t :: %__MODULE__{
          linked_in_id: String.t() | nil,
          name: String.t() | nil,
          universal_name: String.t() | nil,
          linked_in_url: String.t() | nil,
          employee_count: integer() | nil,
          employee_count_range: employee_count_range() | nil,
          website_url: String.t() | nil,
          tagline: String.t() | nil,
          description: String.t() | nil,
          industry: String.t() | nil,
          phone: String.t() | nil,
          specialities: [String.t()],
          follower_count: integer() | nil,
          headquarter: headquarter() | nil,
          logo: String.t() | nil,
          founded_on: founded_on() | nil,
          background_url: String.t() | nil,
          funding_data: funding_data() | nil
        }

  defstruct [
    :linked_in_id,
    :name,
    :universal_name,
    :linked_in_url,
    :employee_count,
    :employee_count_range,
    :website_url,
    :tagline,
    :description,
    :industry,
    :phone,
    :follower_count,
    :headquarter,
    :logo,
    :founded_on,
    :background_url,
    :funding_data,
    specialities: []
  ]
end
