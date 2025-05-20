defmodule Core.Ai.Webpage.ProfileIntent do
  @model :claude_sonnet
  @model_temperature 0.2
  @max_tokens 1024

  def profile_intent(nil), do: {:error, "domain cannot be nil"}
  def profile_intent(""), do: {:error, "domain cannot be empty string"}

  def profile_intent(domain) do
    # TODO lookup if webpage is cached 
    case Core.External.Jina.Service.fetch_page(domain) do
      {:ok, content} when is_binary(content) ->
        case Core.Ai.Webpage.Classify.validate_content(content) do
          {:ok, validated_content} ->
            {system_prompt, prompt} = build_profile_intent_prompts(domain, validated_content)

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

      {:ok, content} when not is_binary(content) ->
        {:error, "invalid content type: #{inspect(content)}"}

      {:error, reason} ->
        {:error, "unable to fetch webpage with jina: #{inspect(reason)}"}
    end

    ## TODO add output validation & save to DB
  end

  defp build_profile_intent_prompts(_domain, content) when content == "" do
    {:error, "content cannot be empty"}
  end

  defp build_profile_intent_prompts(_domain, content) when not is_binary(content) do
    {:error, "invalid content type"}
  end

  defp build_profile_intent_prompts(domain, content) do
    system_prompt = """
      I will provide you with the scraped content of a webpage along with company metadata.

    Your job is to score the content across 4 stages of the buyer's journey, evaluating how well it addresses buyer needs at each stage:

    1. Problem Recognition (identifying challenges/pain points)
    2. Solution Research (educating about approaches/methodologies)
    3. Evaluation (comparing options, features, case studies)
    4. Purchase Readiness (pricing, demos, trials, CTAs)

    Score each stage 1-5:
    1: Not relevant for this stage
    2: Slightly relevant
    3: Moderately relevant
    4: Very relevant
    5: Highly relevant

    Return ONLY a JSON object in this exact format:
    {
    "problem_recognition": 3,
    "solution_research": 5,
    "evaluation": 2,
    "purchase_readiness": 1
    }
    """

    prompt = """
          Domain: #{domain}
          URL Content: #{content}
    """

    {system_prompt, prompt}
  end
end
