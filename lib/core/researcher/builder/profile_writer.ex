defmodule Core.Researcher.Builder.ProfileWriter do
  @moduledoc """
  Generates Ideal Customer Profiles (ICPs) based on business pages.

  This module manages:
  * ICP generation from business pages
  * AI prompt construction
  * Response validation and parsing
  * Profile data extraction
  * Error handling and retries

  It coordinates the generation of actionable ICPs by analyzing
  business pages, constructing prompts for AI evaluation, and
  validating the responses. The module ensures generated profiles
  are well-structured and contain all necessary information for
  effective lead evaluation.
  """

  alias Core.Researcher.Builder.ProfileValidator
  alias Core.Researcher.Webpages
  alias Core.Researcher.Errors
  alias Core.Ai

  @model :claude_sonnet
  @model_temperature 0.2
  @max_tokens 2048
  @timeout 60 * 1000

  def generate_icp(domain) when is_binary(domain) do
    with {:ok, pages} <-
           Webpages.get_business_pages_by_domain(
             domain,
             limit: 10
           ),
         {system_prompt, prompt} <- build_prompts(domain, pages) do
      ask_ai_for_icp(build_request(system_prompt, prompt))
    else
      {:error, reason} -> Errors.error(reason)
    end
  end

  defp ask_ai_for_icp(request) do
    task = Ai.ask_supervised(request)

    case Task.yield(task, @timeout) do
      {:ok, {:ok, answer}} ->
        ProfileValidator.validate_and_parse(answer)

      {:ok, {:error, reason}} ->
        Errors.error(reason)

      {:exit, reason} ->
        Errors.error(reason)

      nil ->
        Task.shutdown(task)
        Errors.error(:timeout)
    end
  end

  defp build_request(system_prompt, prompt) do
    Ai.Request.new(prompt,
      model: @model,
      system_prompt: system_prompt,
      max_tokens: @max_tokens,
      temperature: @model_temperature
    )
  end

  defp build_prompts(domain, business_pages) do
    system_prompt = """
    I will provide you with a B2B company and relevant content from their website.  Your job is to build an actionable ideal customer profile that can be used to accurately qualify all leads.  The ideal customer profile will consist of two parts:
    1. A concise descriptive paragraph of the ideal customer profile for the business
    2. Up to 5 qualifying attributes of a company that matches the ideal customer profile
    IMPORTANT:  Your response MUST be in valid JSON format exactly matching this schema:
      {
        "profile": "Mid-to-large organizations with significant marketing budgets who receive a high volume of high-value phone calls as part of their customer journey. These companies typically operate in sectors where phone conversations lead to meaningful conversions (financial services, automotive, healthcare, travel, property, retail) and struggle to connect their digital marketing efforts to offline call outcomes. They're sophisticated marketers who invest substantially in multi-channel campaigns but face attribution challenges when customers move from online research to phone conversations. The most receptive customers tend to have average transaction values over £1,000, making precise marketing attribution critical for ROI optimization, and employ dedicated marketing analytics teams who recognize the value gap in their current attribution models. They're often frustrated by wasted ad spend and inability to prove which campaigns truly drive revenue.
    ",
        "qualifying_attributes": [
          "Companies that receive at least 500+ valuable phone calls per month from digital marketing efforts.",
          "Businesses where phone conversations typically lead to transactions worth £1,000+ or significant lifetime value.",
          "Sectors where complex purchases often require phone conversations (financial services, automotive, healthcare, property, travel, etc.)"
        ]
      }
    Do not include any text outside the JSON object.
    """

    prompt = build_company_context_prompt(domain, business_pages)

    {system_prompt, prompt}
  end

  defp build_company_context_prompt(domain, business_pages) do
    """
    Company Domain: #{domain}

    #{build_company_analysis(business_pages)}

    #{build_page_content_section(business_pages)}
    """
  end

  def build_company_analysis(business_pages) do
    sections = []

    # Add industry and vertical information
    sections = add_industry_section(sections, business_pages)

    # Add solutions and topics
    sections = add_solutions_section(sections, business_pages)

    # Add value propositions
    sections = add_value_props_section(sections, business_pages)

    # Add pain points they address
    sections = add_pain_points_section(sections, business_pages)

    # Add customer references
    sections = add_customers_section(sections, business_pages)

    # Add content types summary
    sections = add_content_summary(sections, business_pages)

    sections
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n\n")
  end

  def build_page_content_section(business_pages) do
    content_sections =
      business_pages
      |> Enum.with_index(1)
      |> Enum.map_join("\n\n", fn {page, index} ->
        build_individual_page_content(page, index)
      end)

    """
    WEBSITE CONTENT:

    #{content_sections}
    """
  end

  defp build_individual_page_content(page, index) do
    # Use summary if available, otherwise fall back to truncated content
    page_content = get_page_content(page)

    """
    PAGE #{index} (#{page.content_type || "unknown"}):
    URL: #{page.url}
    #{if page.primary_topic, do: "Topic: #{page.primary_topic}\n", else: ""}#{if page.value_proposition, do: "Value Prop: #{page.value_proposition}\n", else: ""}
    Content:
    #{page_content}
    """
  end

  defp get_page_content(page) do
    cond do
      # Prefer summary if it exists and is not empty
      page.summary && String.trim(page.summary) != "" ->
        page.summary

      # Fall back to truncated content if no summary
      page.content ->
        truncate_content(page.content, 800)

      # Handle case where neither exists
      true ->
        "No content available"
    end
  end

  defp truncate_content(nil, _max_length), do: ""

  defp truncate_content(content, max_length)
       when byte_size(content) <= max_length,
       do: content

  defp truncate_content(content, max_length) do
    truncated = String.slice(content, 0, max_length)
    # Try to break at a word boundary
    case String.last(truncated) do
      " " ->
        truncated <> "..."

      _ ->
        # Find the last space and cut there
        case String.split(truncated) |> Enum.drop(-1) |> Enum.join(" ") do
          "" -> truncated <> "..."
          word_bounded -> word_bounded <> "..."
        end
    end
  end

  defp add_industry_section(sections, business_pages) do
    industries =
      business_pages
      |> Enum.map(& &1.industry_vertical)
      |> Enum.filter(&(&1 != nil and &1 != ""))
      |> Enum.uniq()

    if Enum.any?(industries) do
      section = "Industry Verticals: #{Enum.join(industries, ", ")}"
      [section | sections]
    else
      sections
    end
  end

  defp add_solutions_section(sections, business_pages) do
    # Get primary topics
    primary_topics =
      business_pages
      |> Enum.map(& &1.primary_topic)
      |> Enum.filter(&(&1 != nil and &1 != ""))
      |> Enum.uniq()

    # Get solution focus areas
    solution_focuses =
      business_pages
      |> Enum.flat_map(&(&1.solution_focus || []))
      |> Enum.uniq()

    # Get secondary topics
    secondary_topics =
      business_pages
      |> Enum.flat_map(&(&1.secondary_topics || []))
      |> Enum.uniq()

    # Build solutions content list
    solutions_content =
      [
        if(Enum.any?(primary_topics),
          do: "Primary Topics: #{Enum.join(primary_topics, ", ")}"
        ),
        if(Enum.any?(solution_focuses),
          do: "Solution Focus Areas: #{Enum.join(solution_focuses, ", ")}"
        ),
        if(Enum.any?(secondary_topics),
          do: "Secondary Topics: #{Enum.join(secondary_topics, ", ")}"
        )
      ]
      |> Enum.filter(&(&1 != nil))

    if Enum.any?(solutions_content) do
      section = "Solutions & Topics:\n" <> Enum.join(solutions_content, "\n")
      [section | sections]
    else
      sections
    end
  end

  defp add_value_props_section(sections, business_pages) do
    value_props =
      business_pages
      |> Enum.map(& &1.value_proposition)
      |> Enum.filter(&(&1 != nil and &1 != ""))
      |> Enum.uniq()

    if Enum.any?(value_props) do
      section =
        "Value Propositions:\n" <>
          Enum.map_join(
            Enum.with_index(value_props, 1),
            "\n",
            fn {prop, idx} -> "#{idx}. #{prop}" end
          )

      [section | sections]
    else
      sections
    end
  end

  defp add_pain_points_section(sections, business_pages) do
    pain_points =
      business_pages
      |> Enum.flat_map(&(&1.key_pain_points || []))
      |> Enum.uniq()

    if Enum.any?(pain_points) do
      section = "Key Pain Points Addressed: #{Enum.join(pain_points, ", ")}"
      [section | sections]
    else
      sections
    end
  end

  defp add_customers_section(sections, business_pages) do
    customers =
      business_pages
      |> Enum.flat_map(&(&1.referenced_customers || []))
      |> Enum.uniq()

    if Enum.any?(customers) do
      section = "Referenced Customers: #{Enum.join(customers, ", ")}"
      [section | sections]
    else
      sections
    end
  end

  defp add_content_summary(sections, business_pages) do
    content_types =
      business_pages
      |> Enum.map(& &1.content_type)
      |> Enum.filter(&(&1 != nil and &1 != ""))
      |> Enum.frequencies()

    if Enum.any?(content_types) do
      type_summary =
        Enum.map_join(content_types, ", ", fn {type, count} ->
          "#{count} #{type}"
        end)

      section =
        "Content Analysis: #{type_summary} (#{length(business_pages)} total pages analyzed)"

      [section | sections]
    else
      sections
    end
  end
end
