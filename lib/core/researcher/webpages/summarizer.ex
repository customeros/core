defmodule Core.Researcher.Webpages.Summarizer do
  alias Core.Researcher.Errors
  alias Core.Ai
  @model :claude_sonnet
  @model_temperature 0.2
  @max_tokens 1024
  @timeout 60 * 1000

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
        temperature: @model_temperature
      )

    task = Ai.ask_supervised(request)

    case Task.yield(task, @timeout) do
      {:ok, answer} ->
        answer

      {:exit, reason} ->
        Errors.error(reason)

      nil ->
        Task.shutdown(task)
        Errors.error(:content_summary_timeout)
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
