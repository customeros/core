defmodule Core.Researcher.Webpages.Classification do
  @moduledoc """
  Manages the classification of webpages based on various attributes and characteristics.

  This module provides functionality to categorize and classify webpages according to
  different criteria such as content type, purpose, and target audience.
  """

  @derive Jason.Encoder

  @type content_type ::
          :article
          | :whitepaper
          | :webinar
          | :case_study
          | :product_page
          | :solution_page
          | :testimonial
          | :research_report
          | :technical_docs
          | :unknown

  @type t :: %__MODULE__{
          primary_topic: String.t(),
          secondary_topics: list(String.t()),
          solution_focus: list(String.t()),
          content_type: content_type(),
          industry_vertical: String.t(),
          key_pain_points: list(String.t()),
          value_proposition: String.t(),
          referenced_customers: list(String.t())
        }

  defstruct [
    :primary_topic,
    :secondary_topics,
    :solution_focus,
    :content_type,
    :industry_vertical,
    :key_pain_points,
    :value_proposition,
    :referenced_customers
  ]
end
