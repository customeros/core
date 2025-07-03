defmodule Core.ScrapinContactResponseBody do
  @moduledoc """
  Struct for the root ScrapIn API response body.
  Matches the JSON response structure for contact enrichment.
  """

  @derive Jason.Encoder
  alias Core.ScrapinContactDetails
  alias Core.ScrapinCompanyDetails

  @type t :: %__MODULE__{
          success: boolean(),
          email: String.t() | nil,
          email_type: String.t() | nil,
          credits_left: integer() | nil,
          rate_limit_left: integer() | nil,
          person: ScrapinContactDetails.t() | nil,
          company: ScrapinCompanyDetails.t() | nil
        }

  defstruct [
    :success,
    :email,
    :email_type,
    :credits_left,
    :rate_limit_left,
    :person,
    :company
  ]
end
