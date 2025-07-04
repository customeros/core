defmodule Core.Researcher.Webpages.IntentProfiler do
  @moduledoc """
  Profiles webpage intent using AI.
  """
  alias Core.Ai
  alias Core.Utils.Tracing
  alias Core.Utils.TaskAwaiter
  require Logger

  @model :claude_sonnet_4_0
  @model_temperature 0.2
  @max_tokens 1024
  @timeout 60 * 1000

  alias Core.Researcher.Webpages.Intent

  def profile_intent_supervised(url, content) do
    Task.Supervisor.async(
      Core.TaskSupervisor,
      fn ->
        profile_intent(url, content)
      end
    )
  end

  def profile_intent(_url, content) when content == "" do
    Tracing.error(:empty_content)
    {:error, :empty_content}
  end

  def profile_intent(_url, content) when not is_binary(content) do
    Tracing.error(:invalid_content_type)
    {:error, :invalid_content_type}
  end

  def profile_intent(url, content) when is_binary(content) and content != "" do
    Logger.info("Starting profile intent analysis for #{url}",
      url: url
    )

    {system_prompt, prompt} = build_profile_intent_prompts(url, content)

    request =
      Ai.Request.new(prompt,
        model: @model,
        system_prompt: system_prompt,
        max_tokens: @max_tokens,
        temperature: @model_temperature
      )

    task = Ai.ask_supervised(request)

    case TaskAwaiter.await(task, @timeout) do
      {:ok, answer} ->
        case parse_and_validate_response(answer) do
          {:ok, profile_intent} -> {:ok, profile_intent}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def profile_webpage_intent(_url, content) when content == "" do
    {:error, "content cannot be empty"}
  end

  def profile_webpage_intent(_url, content) when not is_binary(content) do
    {:error, "invalid content type"}
  end

  defp parse_and_validate_response(response) when is_binary(response) do
    with {:ok, json_data} <- Jason.decode(response),
         {:ok, profile_intent} <- validate_and_build_profile_intent(json_data) do
      {:ok, profile_intent}
    else
      {:error, %Jason.DecodeError{}} ->
        {:error, :invalid_json_format}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_and_build_profile_intent(json_data) when is_map(json_data) do
    with {:ok, problem_recognition} <-
           validate_score(
             json_data["problem_recognition"],
             "problem_recognition"
           ),
         {:ok, solution_research} <-
           validate_score(json_data["solution_research"], "solution_research"),
         {:ok, evaluation} <-
           validate_score(json_data["evaluation"], "evaluation"),
         {:ok, purchase_readiness} <-
           validate_score(json_data["purchase_readiness"], "purchase_readiness") do
      profile_intent = %Intent{
        problem_recognition: problem_recognition,
        solution_research: solution_research,
        evaluation: evaluation,
        purchase_readiness: purchase_readiness
      }

      {:ok, profile_intent}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_score(score, _field_name)
       when is_integer(score) and score >= 1 and score <= 5 do
    {:ok, score}
  end

  defp validate_score(score, field_name) when is_float(score) do
    rounded_score = round(score)

    if rounded_score >= 1 and rounded_score <= 5 do
      {:ok, rounded_score}
    else
      {:error,
       "Invalid #{field_name}: score must be between 1 and 5, got #{score}"}
    end
  end

  defp validate_score(score, field_name) when is_binary(score) do
    case Integer.parse(score) do
      {parsed_score, ""} when parsed_score >= 1 and parsed_score <= 5 ->
        {:ok, parsed_score}

      {parsed_score, ""} ->
        {:error,
         "Invalid #{field_name}: score must be between 1 and 5, got #{parsed_score}"}

      _ ->
        {:error, "Invalid #{field_name}: could not parse '#{score}' as integer"}
    end
  end

  defp validate_score(nil, field_name) do
    {:error, "Missing required field: #{field_name}"}
  end

  defp validate_score(score, field_name) do
    {:error,
     "Invalid #{field_name}: expected integer between 1-5, got #{inspect(score)}"}
  end

  defp build_profile_intent_prompts(url, content) do
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

    IMPORTANT: Return ONLY a JSON object in this exact format with integer values:
    {
      "problem_recognition": 3,
      "solution_research": 5,
      "evaluation": 2,
      "purchase_readiness": 1
    }

    Do not include any text outside the JSON object. Each score must be an integer from 1 to 5.
    """

    prompt = """
    URL: #{url}
    Content: #{content}
    """

    {system_prompt, prompt}
  end
end
