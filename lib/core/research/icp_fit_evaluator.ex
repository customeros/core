defmodule Core.Research.IcpFitEvaluator do
  @model :claude_sonnet
  @model_temperature 0.2
  @max_tokens 156

  def evaluate(tenant_id, domain) do
    with {:ok, icp} <- Core.Research.IcpProfiles.get_by_tenant_id(tenant_id),
         {:ok, _scraped_data} <-
           Core.Research.Crawler.start(domain),
         {:ok, pages} <-
           Core.Research.ScrapedWebpages.get_business_pages_by_domain(domain,
             limit: 10
           ),
         {:ok, fit} <- get_icp_fit(domain, pages, icp) do
      {:ok, fit}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_icp_fit(domain, pages, icp) do
    {system_prompt, prompt} = build_prompts(domain, pages, icp)

    with {:ok, answer} <-
           Core.Ai.AskAi.ask(build_request(system_prompt, prompt)),
         {:ok, fit} <-
           Core.Research.Evaluator.FitValidator.validate_and_parse(answer) do
      {:ok, fit}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_request(system_prompt, prompt) do
    %Core.Ai.AskAi.AskAIRequest{
      model: @model,
      prompt: prompt,
      system_prompt: system_prompt,
      max_output_tokens: @max_tokens,
      model_temperature: @model_temperature
    }
  end

  defp build_prompts(domain, business_pages, icp) do
    system_prompt = """
      I will provide you with a B2B company and relevant context from their website.  I will also provide you with a description of my ideal customer profile and qualifying criteria.  Your job is to determine how well the company matches my ideal customer profile.  Valid response values are "strong", "moderate", "not a fit".  Please only return one of these three values.
      IMPORTANT:  Your response MUST be in valid JSON format exactly maching this schema:
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
