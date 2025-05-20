defmodule Core.Ai.Webpage.Classify do
  @model :claude_sonnet
  @model_temperature 0.2
  @max_tokens 1024
  @error_unprocessable "unable to scrape webpage"

  def classify_webpage(nil), do: {:error, "domain cannot be nil"}
  def classify_webpage(""), do: {:error, "domain cannot be empty string"}

  def classify_webpage(domain) when is_binary(domain) do
    case Core.External.Jina.Service.fetch_page(domain) do
      {:ok, content} ->
        case validate_content(content) do
          {:ok, validated_content} ->
            {system_prompt, prompt} = build_classify_webpage_prompts(domain, validated_content)

            request = %Core.Ai.AskAi.AskAIRequest{
              model: @model,
              prompt: prompt,
              system_prompt: system_prompt,
              max_output_tokens: @max_tokens,
              model_temperature: @model_temperature
            }

            case Core.Ai.AskAi.ask(request) do
              {:ok, answer} -> {:ok, answer}
              {:error, reason} -> {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, "unable to fetch webpage with jina: #{inspect(reason)}"}
    end

    ## TODO add output validation & save to DB
  end

  def validate_content(content) do
    cond do
      content == "" ->
        {:error, @error_unprocessable}

      String.contains?(content, "403 Forbidden") ->
        {:error, @error_unprocessable}

      String.contains?(content, "Robot Challenge") ->
        {:error, @error_unprocessable}

      String.contains?(content, "no content") ->
        {:error, @error_unprocessable}

      true ->
        {:ok, content}
    end
  end

  defp build_classify_webpage_prompts(domain, content) do
    system_prompt = """
          I will provide you with the scraped content of a webpage along with some metadata about the company it belongs to.  Your job is to classify the content based on:
        - Primary Topic
        - Secondary Topics (0-3 values)
        - The Solution(s) the content is focused on (1-3 values)
        - The type of content it is (e.g. case study, product page, documentation, ect)
        - The Industry Vertical the content is targeting
        - The Key Pain Points the content aims to address (1-3 values)
        - The core Value Proposition of the content
        - A list of all Referenced Customers contained within the content
        - Valid content types must match one of the following:
            - article
            - whitepaper
            - webinar
            - case study
            - product page
            - solution page
            - testimonial
            - research report
            - technical documentation

        IMPORTANT: Your response MUST be in valid JSON format exactly maching this schema:
        {
          "primary_topic": "Cloud Migration Strategy",
          "secondary_topics": [
            "Digital Transformation",
            "Infrastructure Modernization",
            "DevOps Adoption"
          ],
          "solution_focus": [
            "AWS Migration Services",
            "Container Management"
          ],
          "content_type": "Technical Whitepaper",
          "industry_vertical": "Financial Services",
          "key_pain_points": [
            "Legacy system maintenance costs",
            "Scalability limitations",
            "Security compliance requirements",
            "Slow deployment cycles"
          ],
          "value_proposition": "Reduce operational costs by 40% while improving deployment speed",
          "referenced_customers": [
            "JP Morgan Chase",
            "Bank of America",
            "Wells Fargo",
            "Capital One"
          ]
        }
        Do not include any text outside the JSON object.  If you are unable to confidently determine a value, return an empty string.
    """

    prompt = """
          Domain: #{domain}
          URL Content: #{content}
    """

    {system_prompt, prompt}
  end
end
