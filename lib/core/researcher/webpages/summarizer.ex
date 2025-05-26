defmodule Core.Researcher.Webpages.Summarizer do
  alias Core.Ai
  @model :claude_sonnet
  @model_temperature 0.2
  @max_tokens 1024

  def summarize_webpage(url, content) when is_binary(content) do
    {system_prompt, prompt} = build_prompts(url, content)

    request = %Ai.Request{
      model: @model,
      prompt: prompt,
      system_prompt: system_prompt,
      max_output_tokens: @max_tokens,
      model_temperature: @model_temperature
    }

    Ai.ask_with_timeout(request)
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
