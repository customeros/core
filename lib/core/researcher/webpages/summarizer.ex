defmodule Core.Researcher.Webpages.Summarizer do
  @moduledoc """
  Provides AI-powered webpage content summarization functionality.

  This module handles:
  - Webpage content summarization using Claude AI
  - Supervised and unsupervised summarization tasks
  - Prompt construction and management
  - Timeout handling and error management
  - Integration with AI services
  - Task supervision for long-running operations
  """

  alias Core.Ai
  alias Core.Utils.TaskAwaiter

  @model :gemini_flash
  @model_temperature 0.2
  @max_tokens 1024
  @timeout 60 * 1000

  @err_timeout {:error, "generating content summary timed out"}

  def summarize_webpage_supervised(url, content) do
    Task.Supervisor.async(
      Core.TaskSupervisor,
      fn ->
        summarize_webpage(url, content)
      end
    )
  end

  def summarize_webpage(url, content) when is_binary(content) do
    {system_prompt, prompt} = build_prompts(url, content)

    request =
      Ai.Request.new(prompt,
        model: @model,
        system_prompt: system_prompt,
        max_tokens: @max_tokens,
        temperature: @model_temperature,
        response_type: :text
      )

    task = Ai.ask_supervised(request)

    case TaskAwaiter.await(task, @timeout) do
      {:ok, answer} ->
        {:ok, answer}

      {:error, :timeout} ->
        @err_timeout

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_prompts(url, content) do
    system_prompt = """
    I will provide you with the scraped content of a webpage. Your job is to summarize the content of the website without losing any critical or important information.  IMPORTANT:  Do not editorialize or otherwise comment on the content.  Only return the summary.
    """

    prompt = """
    Url: #{url}
    Content: #{content}
    """

    {system_prompt, prompt}
  end
end
