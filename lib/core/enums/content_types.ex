defmodule Core.Enums.ContentTypes do
  @moduledoc """
  Defines the various types of content that can be found on a website.

  This enum categorizes different content formats and pages, from educational materials
  to product information and company pages, helping in content classification and analysis.
  """

  @content_type [
    :educational_article,
    :infographic,
    :research_report,
    :whitepaper,
    :webinar,
    :solution_guide,
    :implementation_guide,
    :technical_doc,
    :case_study,
    :customer_story,
    :testimonial,
    :comparison,
    :roi,
    :product_page,
    :solution_page,
    :homepage,
    :pricing,
    :contact,
    :about,
    :legal,
    :resource_navigation,
    :signup,
    :landing_page,
    :jobs,
    :other
  ]

  def content_types, do: @content_type
end
