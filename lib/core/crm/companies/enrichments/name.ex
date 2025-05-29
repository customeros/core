defmodule Core.Crm.Companies.Enrichments.Name do
  require Logger
  alias Core.Ai

  @timeout 60 * 1000
  @model :claude_sonnet
  @max_tokens 250
  @temperature 0.1
  @system_prompt """
  I'm going to provide you metadata about a company, including their website content.
  Your job is to identify the commonly recognized brand name of the company.

  Important rules:
  1. Return ONLY the commonly recognized brand name, nothing else.
  2. If the company is more commonly known by a brand name (e.g., "Apple" instead of "Apple Inc."), use that simpler name.
  3. Remove all suffixes like Inc, Ltd, LLC, Corp, etc.
  4. Use title case EXCEPT when:
     - The brand is officially spelled in uppercase (e.g., "UPS", "HSBC")
     - The brand officially starts with lowercase (e.g., "eBay", "iPhone")
  5. Focus on the most recognizable, consumer-facing name.
  """

  @type input :: %{
          domain: String.t(),
          homepage_content: String.t()
        }

  @spec identify(input()) :: {:ok, String.t()} | {:error, term()}
  def identify(%{domain: domain, homepage_content: content}) do
    prompt = build_prompt(domain, content)

    request =
      Ai.Request.new(prompt,
        model: @model,
        system_prompt: @system_prompt,
        max_tokens: @max_tokens,
        temperature: @temperature
      )

    task = Ai.ask_supervised(request)

    case Task.yield(task, @timeout) do
      {:ok, {:ok, response}} ->
        name =
          response
          |> String.trim()
          # Remove any additional lines
          |> String.replace(~r/\n.*$/, "")
          # Remove surrounding quotes if any
          |> String.replace(~r/^["']|["']$/, "")

        if String.length(name) > 0 do
          {:ok, name}
        else
          {:error, :invalid_ai_response}
        end

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:exit, reason} ->
        {:error, reason}

      nil ->
        Task.shutdown(task)
        {:error, :ai_timeout}
    end
  end

  defp build_prompt(domain, content) do
    """
    Website: #{domain}

    ---Homepage content---
    #{content}
    """
  end
end
