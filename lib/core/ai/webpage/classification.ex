defmodule Core.Ai.Webpage.Classification do
  @moduledoc """
  Represents the classification of a webpage.
  """

  @type content_type :: :article | :whitepaper | :webinar | :case_study | :product_page |
                      :solution_page | :testimonial | :research_report | :technical_docs | :unknown

  @type t :: %__MODULE__{
    primary_topic: String.t() | nil,
    secondary_topics: [String.t()] | nil,
    solution_focus: [String.t()] | nil,
    content_type: content_type() | nil,
    industry_vertical: String.t() | nil,
    key_pain_points: [String.t()] | nil,
    value_proposition: String.t() | nil,
    referenced_customers: [String.t()] | nil
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

  defimpl Jason.Encoder, for: __MODULE__ do
    def encode(struct, opts) do
      Jason.Encode.map(Map.from_struct(struct), opts)
    end
  end
end
