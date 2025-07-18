defmodule Core.Researcher.BriefWriter.AccountResearcher do
  @moduledoc """
  Generates an account overview for a given lead, tailored to a specific tenant's value proposition.
  """
  require Logger

  alias Core.Ai
  alias Core.Utils.TaskAwaiter
  alias Core.Researcher.Webpages
  alias Core.Researcher.IcpProfiles
  alias Core.Utils.MarkdownValidator

  @max_tokens 2056
  @model :claude_sonnet_4_0
  @model_temperature 0.3
  @timeout 60_000

  def account_overview(tenant_id, lead_domain) do
    with {:ok, icp} <- IcpProfiles.get_by_tenant_id(tenant_id),
         {:ok, pages} <-
           Webpages.get_business_pages_by_domain(lead_domain, limit: 8),
         request <- build_request(lead_domain, icp, pages),
         {:ok, overview} <- generate_account_overview(request),
         {:ok, validated_overview} <-
           MarkdownValidator.validate_and_clean(overview) do
      {:ok, validated_overview}
    else
      {:error, reason} ->
        Logger.error("Failed to generate account overview: #{inspect(reason)}",
          tenant_id: tenant_id,
          domain: lead_domain
        )

        {:error, reason}
    end
  end

  defp build_request(domain, icp, business_pages) do
    {system_prompt, prompt} =
      build_prompts(domain, business_pages, icp)

    build_ai_request(system_prompt, prompt)
  end

  defp generate_account_overview(request) do
    task = Ai.ask_supervised(request)
    TaskAwaiter.await(task, @timeout)
  end

  def build_ai_request(system_prompt, prompt) do
    Ai.Request.new(prompt,
      model: @model,
      system_prompt: system_prompt,
      max_tokens: @max_tokens,
      temperature: @model_temperature
    )
  end

  def build_prompts(domain, business_pages, icp) do
    system_prompt = """
      I will provide you with my ideal customer profile and qualifying criteria.  I will also provide you details about a company that matches my ideal company profile that I want to engage.  Your job is to help me produce an account brief that gives me everything I need to know to start a relevant, high value conversation with this company that helps them solve a real business problem they are likely to have.  Please produce a brief with only these specific sections:
      - Company overview
      - Key services
      - ICP Fit analysis
      - Current business context & compelling events
      - Likely pain points
      - Strategic value drivers

      <MARKDOWN_RULES>
      Your brief must be returned in valid markdown format only!
      Follow these formatting rules strictly:
      - Use ## for section headers (e.g., ## Company Overview)
      - Use - for bullet points
      - Use **text** for bold emphasis, ensure all asterisks are properly matched
      - Use lists consistently with bullet points (-)
      - Keep formatting simple and clean
      - Do not use * or _ for emphasis unless properly matched
      - Ensure proper spacing between sections
      - Do not use HTML tags
      </MARKDOWN_RULES>

      What Makes a Great Account Brief: Quality Standards
    A great brief tells a story that makes the prospect feel like you already understand their business better than 99% of vendors who contact them.
    A great brief is direct and to the point.

    Company Overview Section

    Great: "Fiserv is a global leader in financial services technology, serving 1 in 3 U.S. banks and credit unions across multiple business segments"
    Poor: "Fiserv is a fintech company that does payments"

    Your overview should make it clear you understand their scale, market position, and complexity. Anyone reading it should immediately grasp why this company matters and what makes them unique.

    Key Services Section

    Great: Lists 4-6 specific service lines with brand names (Carat, Clover) showing you understand their product architecture
    Poor: Vague descriptions like "payment solutions and banking services"

    Show you understand how their business actually works, not just what industry they're in.

    ICP Fit Section

    Great: Connects each ICP criterion to specific evidence ("50,000+ monthly calls across merchant services, bank partnerships, customer support")
    Poor: Generic statements like "they're in financial services so they probably make lots of calls"

    Every ICP fit statement needs concrete evidence. Don't guess - prove it.

    Compelling Event Section

    Great: Specific, recent developments with clear business impact ("New CEO Michael P. Lyons taking leadership - likely reviewing operational efficiency")
    Poor: Generic industry trends or outdated news

    The compelling event should create urgency. Ask yourself: "Why would they care about this conversation THIS month?"
    Pain Points Section

    Great: Business-specific challenges derived from their operating model ("Multiple business units operating in silos without unified call tracking")
    Poor: Generic pain points that could apply to any company

    Pain points should feel like you've been inside their business. They should think "How did they know that's exactly what we struggle with?"

    Red Flags to Avoid
      - Surface-Level Research
      - Copying marketing language directly from their website
      - Focusing only on what they sell, not how they operate
      - Missing obvious recent news or changes
      - Generic industry pain points with no company-specific angle
      - Weak ICP Justification
      - Qualifying them based on assumptions rather than evidence
      - Irrelevant Compelling Events
      - Generic Positioning

    The same positioning you'd use for every financial services company
    No acknowledgment of their unique business model
    Proof points that don't match their specific situation

    The "Aha Moment" Test
    A great brief passes this test: If you called the prospect and said "I've been researching your business and I think you're probably struggling with [specific pain point] because of [specific business reality]," they would say "Wait, how did you know that?"
    A poor brief fails this test: The prospect would think "This person clearly just looked at our website for 5 minutes."
    Depth Indicators
    Great briefs demonstrate depth through:

    Specific product/service names and how they interconnect
    Understanding of their customer segments and how they serve each differently
    Recognition of operational complexity (multiple business units, diverse offerings)
    Awareness of competitive pressures specific to their market position
    Connection between recent events and likely internal priorities

    Poor briefs show surface-level research through:

    Only mentioning what's on the homepage
    Generic industry terminology
    No understanding of their business model complexity
    Outdated or irrelevant information
    One-size-fits-all positioning

    The Business Impact Standard
    Every section should connect back to: "Here's why our solution would matter to THIS specific company's business results."
    If you can't draw that line clearly, you need to dig deeper into their business model and operating challenges.
    Remember: The goal isn't just to show you did research. It's to demonstrate that you understand their business well enough to have a strategic conversation about improving it.

    CRITICALLY IMPORTANT: if at any point in your analysis you determine this company is not an ICP fit, DO NOT generate the brief. Simply return the string below, nothing else:
      not_a_fit
    """

    prompt = """
    My Ideal Customer Profile: #{icp.profile}
    My Qualifying Criteria: #{icp.qualifying_attributes}

    Lead's Website: #{domain}

    #{Core.Researcher.IcpBuilder.ProfileWriter.build_company_analysis(business_pages)}

    #{Core.Researcher.IcpBuilder.ProfileWriter.build_page_content_section(business_pages)}
    """

    {system_prompt, prompt}
  end
end
