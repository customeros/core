defmodule Core.Research.IcpFitEvaluator.PromptBuilder do
  @model :claude_sonnet
  @model_temperature 0.2
  @max_tokens 156

  def build_request(system_prompt, prompt) do
    %Core.Ai.AskAi.AskAIRequest{
      model: @model,
      prompt: prompt,
      system_prompt: system_prompt,
      max_output_tokens: @max_tokens,
      model_temperature: @model_temperature
    }
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

    #{Core.Research.Builder.ProfileWriter.build_company_analysis(business_pages)}

    #{Core.Research.Builder.ProfileWriter.build_page_content_section(business_pages)}
    """

    {system_prompt, prompt}
  end
end
