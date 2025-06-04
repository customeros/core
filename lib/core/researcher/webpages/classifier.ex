defmodule Core.Researcher.Webpages.Classifier do
  @moduledoc """
  Classifies webpage content using AI.
  """
  alias Core.Ai
  require Logger

  @model :gemini_pro
  @model_temperature 0.2
  @max_tokens 1024
  @timeout 45 * 1000

  alias Core.Researcher.Webpages.Classification

  def classify_content_supervised(url, content) do
    Task.Supervisor.async(
      Core.TaskSupervisor,
      fn ->
        classify_content(url, content)
      end
    )
  end

  def classify_content(url, content) when is_binary(content) do
    Logger.info("Starting classify content analysis for #{url}",
      url: url
    )

    {system_prompt, prompt} =
      build_classify_webpage_prompts(url, content)

    request =
      Ai.Request.new(prompt,
        model: @model,
        system_prompt: system_prompt,
        temperature: @model_temperature,
        max_tokens: @max_tokens,
        response_type: :json
      )

    task = Ai.ask_supervised(request)

    case Task.yield(task, @timeout) do
      {:ok, {:ok, answer}} ->
        case parse_and_validate_response(answer) do
          {:ok, classification} -> {:ok, classification}
          {:error, reason} -> {:error, reason}
        end

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:exit, reason} ->
        {:error, reason}

      nil ->
        Task.shutdown(task)
        {:error, :timeout}
    end
  end

  defp parse_and_validate_response(response) when is_binary(response) do
    with {:ok, json_data} <- Jason.decode(response),
         {:ok, classification} <- validate_and_build_classification(json_data) do
      {:ok, classification}
    else
      {:error, %Jason.DecodeError{}} ->
        {:error, :invalid_json_format}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_and_build_classification(json_data) when is_map(json_data) do
    with {:ok, content_type} <-
           validate_content_type(json_data["content_type"]),
         {:ok, secondary_topics} <-
           validate_list_field(
             json_data["secondary_topics"],
             "secondary_topics"
           ),
         {:ok, solution_focus} <-
           validate_list_field(json_data["solution_focus"], "solution_focus"),
         {:ok, key_pain_points} <-
           validate_list_field(json_data["key_pain_points"], "key_pain_points"),
         {:ok, referenced_customers} <-
           validate_list_field(
             json_data["referenced_customers"],
             "referenced_customers"
           ) do
      classification = %Classification{
        primary_topic: normalize_string(json_data["primary_topic"]),
        secondary_topics: secondary_topics,
        solution_focus: solution_focus,
        content_type: content_type,
        industry_vertical: normalize_string(json_data["industry_vertical"]),
        key_pain_points: key_pain_points,
        value_proposition: normalize_string(json_data["value_proposition"]),
        referenced_customers: referenced_customers
      }

      {:ok, classification}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_content_type(nil), do: {:ok, :unknown}
  defp validate_content_type(""), do: {:ok, :unknown}

  defp validate_content_type(content_type) when is_binary(content_type) do
    normalized =
      content_type
      |> String.downcase()
      |> String.replace(
        ["technical documentation", "technical docs"],
        "technical_docs"
      )
      |> String.replace(" ", "_")

    valid_types = [
      "article",
      "whitepaper",
      "webinar",
      "case_study",
      "product_page",
      "solution_page",
      "testimonial",
      "research_report",
      "technical_docs"
    ]

    if normalized in valid_types do
      {:ok, String.to_atom(normalized)}
    else
      # Try to match partial strings for common variations
      case find_closest_match(normalized, valid_types) do
        nil -> {:ok, :unknown}
        match -> {:ok, String.to_atom(match)}
      end
    end
  end

  defp validate_content_type(_), do: {:ok, :unknown}

  defp find_closest_match(input, valid_types) do
    valid_types
    |> Enum.find(fn valid_type ->
      String.contains?(input, valid_type) or String.contains?(valid_type, input)
    end)
  end

  defp validate_list_field(nil, _field_name), do: {:ok, []}
  defp validate_list_field([], _field_name), do: {:ok, []}

  defp validate_list_field(list, _field_name) when is_list(list) do
    cleaned_list =
      list
      |> Enum.filter(&is_binary/1)
      |> Enum.map(&normalize_string/1)
      |> Enum.filter(&(&1 != ""))

    {:ok, cleaned_list}
  end

  defp validate_list_field(value, _field_name) when is_binary(value) do
    # Handle case where AI returns a single string instead of array
    if String.trim(value) == "" do
      {:ok, []}
    else
      {:ok, [normalize_string(value)]}
    end
  end

  defp validate_list_field(_value, field_name) do
    {:error, "Invalid #{field_name}: expected list of strings"}
  end

  defp normalize_string(nil), do: ""
  defp normalize_string(str) when is_binary(str), do: String.trim(str)
  defp normalize_string(_), do: ""

  defp build_classify_webpage_prompts(url, content) do
    system_prompt = """
          I will provide you with the scraped content of a webpage along with some metadata about the company it belongs to.  Your job is to classify the content based on:
        - Primary Topic
        - Secondary Topics (0-3 values)
        - The Solution(s) the content is focused on (1-3 values)
        - The type of content it is (e.g. case study, product page, documentation, ect)
        - The Industry Vertical the content is targeting
        - The Key Pain Points the content aims to address (1-3 values)
        - The core Value Proposition of the content
        - A list of all Referenced Customers contained within the content.  Only include companies.  No individuals.
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
        Do not include any text outside the JSON object. Return only a SINGLE classification object (not an array). If you are unable to confidently determine a value, return an empty string.
    """

    prompt = """
          URL: #{url}
          Content: #{content}
    """

    {system_prompt, prompt}
  end
end
