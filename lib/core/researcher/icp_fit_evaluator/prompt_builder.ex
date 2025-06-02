defmodule Core.Researcher.IcpFitEvaluator.PromptBuilder do
  @moduledoc """
  Constructs prompts for evaluating how well a potential customer fits an Ideal Customer Profile (ICP).

  This module is responsible for building and formatting prompts that are used to assess
  the fit between a potential customer and defined ICP criteria. It helps in generating
  structured prompts for AI-based ICP fit evaluation.
  """

  alias Core.Ai
  @model :claude_sonnet
  @model_temperature 0.2
  @max_tokens 156

  def build_request(system_prompt, prompt) do
    Ai.Request.new(prompt,
      model: @model,
      system_prompt: system_prompt,
      max_tokens: @max_tokens,
      temperature: @model_temperature
    )
  end

  def build_prompts(domain, business_pages, icp) do
    system_prompt = """
      I will provide you with a B2B company and relevant context from their website.  I will also provide you with a description of my ideal customer profile and qualifying criteria.  Your job is to determine how well the company matches my ideal customer profile.  Valid response values are "strong", "moderate", "not a fit".  Please only return one of these three values.
      IMPORTANT:  Your response MUST be in valid JSON format exactly matching this schema:
      {
        "icp_fit": "strong"
      }
    Do not include any text outside the JSON object.
    """

    prompt = """
    My Ideal Customer Profile: #{icp.profile}
    My Qualifying Criteria: #{icp.qualifying_attributes}

    Lead's Website: #{domain}

    #{Core.Researcher.Builder.ProfileWriter.build_company_analysis(business_pages)}

    #{Core.Researcher.Builder.ProfileWriter.build_page_content_section(business_pages)}
    """

    {system_prompt, prompt}
  end
end
