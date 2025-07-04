defmodule Core.Researcher.IcpFitEvaluator.PromptBuilder do
  @moduledoc """
  Constructs prompts for evaluating how well a potential customer fits an Ideal Customer Profile (ICP).

  This module is responsible for building and formatting prompts that are used to assess
  the fit between a potential customer and defined ICP criteria. It helps in generating
  structured prompts for AI-based ICP fit evaluation.
  """

  alias Core.Researcher.Scraper
  alias Core.Ai
  @model :gemini_flash_2_0
  @model_temperature 0.2
  @max_tokens 156

  def build_request(system_prompt, prompt) do
    Ai.Request.new(prompt,
      model: @model,
      system_prompt: system_prompt,
      max_tokens: @max_tokens,
      temperature: @model_temperature,
      response_type: :json
    )
  end

  def build_prompts(domain, business_pages, icp) do
    homepage_summary =
      case Scraper.scrape_webpage(domain) do
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
    I will provide you with a B2B company and relevant context from their website. I will also provide you with a description of my business, my ideal customer profile and qualifying criteria. Your job is to determine how well the company matches my ideal customer profile.

    Valid response values are "strong", "moderate", "not_a_fit". 

    IMPORTANT: Err on the side of qualifying companies. Only mark as "not_a_fit" if there are CLEAR disqualifiers that make the company unsuitable. 

      Guidelines for qualification:
    - "strong" -> Company shows good potential and matches key criteria. Look for positive indicators rather than requiring perfect alignment. Consider companies "strong" if they:
    * Match the target industry OR adjacent/related industries that could benefit
    * Are in the right size range OR show growth trajectory toward the ideal size
    * Have business models that could reasonably use our solution
    * Show signs of growth, funding, hiring, or expansion
    * Have pain points our solution addresses (even if not explicitly stated)
    * Operate in our target geography OR have presence/expansion there
    * Are in market segments that historically convert well

    - "moderate" -> Company has some potential but unclear fit, mixed signals, or limited information

    - "not_a_fit" -> Company has clear, fundamental incompatibilities that make them completely unsuitable

    QUALIFICATION MINDSET: 
    - Focus on what COULD work rather than what might not work
    - Give companies the benefit of the doubt when information is unclear
    - Consider growth potential and future needs, not just current state
    - Look for indirect indicators of fit (hiring patterns, funding, partnerships, technology mentions)
    - Remember that companies often don't explicitly state all their pain points on their website
    - Adjacent industries and use cases can still be strong fits
    - If a company seems professional, growing, and in a reasonable industry/size range, lean toward "strong"

    Only return "not_a_fit" if one or more of these MAJOR disqualifiers apply:
    - competitor -> company sells a product or service that directly competes with my product or service
    - wrong_industry -> company operates in an industry that is fundamentally incompatible with our products/services
    - company_too_small -> company is clearly too small for us to service (well below minimum thresholds)
    - company_too_large -> company is clearly too big for us to service effectively (well above maximum thresholds)
    - no_use_case -> there is absolutely no conceivable path to ROI for adopting our product/service
    - wrong_geography -> company operates in a geographic location we cannot serve
    - regulatory_restrictions -> there are insurmountable legal/compliance barriers
    - unable_to_determine_fit -> insufficient information to make any determination

    For edge cases or minor concerns, choose "moderate" instead of "not_a_fit".

    COMPETITOR DEFINITION:
    A company is only considered a "competitor" if they offer a product or service that DIRECTLY substitutes for or replaces our core offering. Be specific and conservative with this designation:

    CLEAR COMPETITORS (mark as "not_a_fit"):
    - Companies that sell the exact same product/service we do
    - Direct substitutes that solve the same core problem in the same way
    - Companies explicitly positioned as alternatives to solutions like ours
    - Vendors whose primary business model directly conflicts with ours

    NOT COMPETITORS (can still be "strong" or "moderate"):
    - Companies that offer complementary products/services (could be integration partners)
    - Vendors in adjacent markets that don't directly compete for the same budget/decision
    - Companies with overlapping features but different primary use cases
    - Platform/ecosystem players where we could potentially integrate
    - Companies targeting different market segments (SMB vs Enterprise) even with similar products
    - Services companies that might resell or implement our solution
    - Companies with some competitive features but primarily different value propositions
    - Potential partners, resellers, or integration opportunities

      Examples:
    - If we sell CRM software, Salesforce = competitor, but marketing automation tools = not competitor
    - If we sell accounting software, QuickBooks = competitor, but tax preparation services = not competitor
    - If we sell HR software, Workday = competitor, but recruiting agencies = not competitor

    IMPORTANT: Your response MUST be in valid JSON format exactly matching this schema:
    {
      "icp_fit": "strong"
    }
    or
    {
      "icp_fit": "moderate"
    }
    or if "not_a_fit"
    {
      "icp_fit": "not_a_fit",
      "reasons": ["competitor", "wrong_industry"]
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
