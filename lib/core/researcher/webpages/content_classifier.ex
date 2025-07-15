defmodule Core.Researcher.Webpages.ContentClassifier do
  require Logger

  import Core.Utils.Pipeline

  alias Core.Ai
  alias Core.Utils.TaskAwaiter
  alias Core.Enums.ContentTypes
  alias Core.Researcher.Scraper

  @classify_model :gemini_flash_2_0
  @scoring_model :llama3_70b
  @fallback_model :claude_sonnet_4_0
  @model_temperature 0.2
  @max_tokens 128
  @timeout 45_000

  def scrape_and_classify(url) do
    with {:ok, webpage} <- Scraper.scrape_webpage(url),
         {:ok, classification} <-
           classify(url, webpage.content),
         {:ok, score} <- score(url, webpage.content, classification) do
      {:ok, classification, score}
    else
      _ -> :error
    end
  end

  def classify_supervised(url, content) do
    Task.Supervisor.async(
      Core.TaskSupervisor,
      fn ->
        classify_and_score(url, content)
      end
    )
  end

  def classify_and_score(url, content) do
    with {:ok, classification} <- classify(url, content),
         {:ok, score} <- score(url, content, classification) do
      {:ok, classification, score}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp classify(url, content) when is_binary(content) do
    Logger.info("Starting classify content analysis for #{url}",
      url: url
    )

    case ask(
           url,
           @classify_model,
           build_classify_prompts(url, content)
         ) do
      {:ok, answer} ->
        validate_classification(answer)

      {:error, _reason} ->
        case ask(
               url,
               @fallback_model,
               build_classify_prompts(url, content)
             ) do
          {:ok, answer} ->
            validate_classification(answer)

          {:error, fallback_error} ->
            Logger.error(
              "failed to classify content at #{url}: #{fallback_error}"
            )

            {:error, fallback_error}
        end
    end
  end

  def score(url, content, content_type) when is_binary(content) do
    Logger.info("Starting content journey scoring analysis for #{url}",
      url: url
    )

    result =
      case content_type do
        :legal ->
          {:ok, "0"}

        :resource_navigation ->
          {:ok, "0"}

        :jobs ->
          {:ok, "0"}

        _ ->
          prompts = build_scoring_prompts(url, content, content_type)

          case ask(url, @scoring_model, prompts) do
            {:ok, answer} ->
              {:ok, answer}

            {:error, _reason} ->
              ask(url, @fallback_model, prompts)
          end
      end

    result |> ok(&validate_score/1)
  end

  defp ask(url, model, {system_prompt, prompt}) do
    request =
      Ai.Request.new(prompt,
        model: model,
        system_prompt: system_prompt,
        temperature: @model_temperature,
        max_tokens: @max_tokens,
        response_type: :text
      )

    task = Ai.ask_supervised(request)

    case TaskAwaiter.await(task, @timeout) do
      {:ok, answer} ->
        {:ok, answer}

      {:error, reason} ->
        Logger.warning(
          "Content classifier request failed for #{url}: #{reason}"
        )

        {:error, reason}
    end
  end

  defp validate_classification(answer) do
    valid_types = ContentTypes.content_types()

    response =
      answer
      |> String.trim()
      |> String.downcase()
      |> String.to_existing_atom()

    if response in valid_types do
      {:ok, response}
    else
      {:error, :invalid_classification}
    end
  end

  defp validate_score(answer) do
    score =
      answer
      |> String.trim()
      |> String.to_integer()

    case score >= 0 && score <= 10 do
      true -> {:ok, score}
      false -> {:error, :invalid_score}
    end
  end

  defp build_classify_prompts(url, content) do
    system_prompt = """
    You will classify webpage content, assess its position in the buyer journey, and analyze the page's primary purpose.  The webpage is scraped from a business website and this data will be used in visitor attribution.

    CONTENT TYPES:
    - educational_article: Articles that describe a problem or pain point, provide industry insights, SEO articles, or anything else that is "selling the problem" more than a solution.
    - infographic: Visual data presentations, illustrated guides
    - research_report: Data studies, industry reports, survey results
    - whitepaper: In-depth technical or strategic documents
    - webinar: Live/recorded presentations, video seminars
    - solution_guide: Step-by-step instructions, best practices, how-to solve a problem (pre-purchase decision)
    - implementation_guide: instructions on how to get setup and running with the solution (post-purchase or during trial)
    - technical_docs: api guides, integration guides or other technical information
    - case_study: Detailed customer success stories with problem/solution/results
    - customer_story: Narrative customer experiences, success stories
    - testimonial: Customer quotes, reviews, recommendations
    - comparison: Product/service comparisons, alternative evaluations
    - roi: ROI calculators, cost analysis tools, financial assessments
    - product_page: Specific product features, benefits, specifications
    - solution_page: Industry/use-case specific solutions, problem-focused pages
    - homepage: Main site landing page, company overview
    - pricing: Pricing plans, cost information, billing details
    - contact: Contact forms, office locations, support information
    - about: Company information, team, mission, history
    - legal: Terms of service, privacy policy, compliance information
    - resource_navigation: Resource listings, content directories, pagination
    - signup: Account creation, registration forms, onboarding
    - landing_page: Campaign-specific pages designed for conversion
    - jobs: Page promoting employment at the company

    CLASSIFICATION RULES:
    1. Choose the PRIMARY purpose of the page
    2. If multiple types apply, prioritize the main user intent
    3. Consider page structure, content depth, and calls-to-action
    4. Score based on the typical mindset of someone consuming this content

    RESPONSE FORMAT: Return only the classification string with no additional text:
      solution_guide
    """

    prompt = """
          URL: #{url}
          Content: #{content}
    """

    {system_prompt, prompt}
  end

  defp build_scoring_prompts(url, content, content_type) do
    system_prompt = """
    You will analyze business webpage content and assess where a potential buyer likely sits in their buyer journey.

    BUYER JOURNEY SCORE (0-10):
    Assess where someone consuming this content likely sits in their buyer journey:
    - 0: Non-relevant (legal pages, careers, jobs, resource navigation pages etc.)
    - 1-3: Education (learning about problems, industry insights)
    - 4-5: Solution (researching solution categories and approaches)
    - 6-8: Evaluation (comparing vendors, detailed product research)
    - 9-10: Ready to Buy (pricing, trials, demos, purchase decisions)

    Consider content depth, specificity, commercial intent, and decision-making focus when scoring.

    RESPONSE FORMAT: Return only a valid integer from 0 to 10 that reflects your decision:
      7
    """

    prompt = """
          URL: #{url}
          Content: #{content}
          Content Type: #{content_type}
    """

    {system_prompt, prompt}
  end
end
