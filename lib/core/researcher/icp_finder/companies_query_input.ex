defmodule Core.Researcher.IcpFinder.CompaniesQueryInput do
  @moduledoc """
  Input for the companies query.
  """

  defstruct [
    :business_model,
    :industry,
    :country_a2,
    :employee_count,
    :employee_count_operator
  ]
end

defmodule Core.Researcher.IcpFinder.TopicsAndIndustriesInput do
  @moduledoc """
  Input for the topics and industries query.
  """

  defstruct topics: [], industry_verticals: []
end
