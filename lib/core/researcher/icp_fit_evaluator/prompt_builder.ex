defmodule Core.Researcher.IcpFitEvaluator.PromptBuilder do
  @moduledoc """
  Constructs prompts for evaluating how well a potential customer fits an Ideal Customer Profile (ICP).

  This module is responsible for building and formatting prompts that are used to assess
  the fit between a potential customer and defined ICP criteria. It helps in generating
  structured prompts for AI-based ICP fit evaluation.
  """

  alias Core.Researcher.Scraper
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
    homepage_summary = case Scraper.scrape_webpage(domain) do
      {:ok, homepage} ->
        case homepage do
          %{summary: summary} when is_binary(summary) ->
            summary

          %{content: content} ->
            String.slice(content, 0, 1000) <> "..."

          _ ->
            "No homepage content available"
        end

      {:error, _reason} ->
        "Unable to scrape homepage content"
    end

    system_prompt = """
      I will provide you with a B2B company and relevant context from their website.  I will also provide you with a description of my business, my ideal customer profile and qualifying criteria.  Your job is to determine how well the company matches my ideal customer profile.  Valid response values are "strong", "moderate", "not a fit".  Please only return one of these three values.
      NOTE: If the company I provide you sells a product or service that is a substitute for my product or service, they are a competitor.  Return "not a fit".
      IMPORTANT:  Your response MUST be in valid JSON format exactly matching this schema:
      {
        "icp_fit": "strong"
      }
    Do not include any text outside the JSON object.
    """

    prompt = """
    About my business: #{homepage_summary}
    My Ideal Customer Profile: #{icp.profile}
    My Qualifying Criteria: #{icp.qualifying_attributes}

    Lead's Website: #{domain}

    #{Core.Researcher.IcpBuilder.ProfileWriter.build_company_analysis(business_pages)}

    #{Core.Researcher.IcpBuilder.ProfileWriter.build_page_content_section(business_pages)}
    """

    {system_prompt, prompt}
  end
end
