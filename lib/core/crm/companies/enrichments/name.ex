defmodule Core.Crm.Companies.Enrichments.Name do
  require Logger
  alias Core.Ai.AskAi
  alias Core.Ai.AskAi.AskAIRequest

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

    request = %AskAIRequest{
      model: :anthropic_claude_3_sonnet,
      prompt: prompt,
      system_prompt: @system_prompt,
      max_output_tokens: 250,
      model_temperature: 0.1
    }

    ai_service = Application.get_env(:core, :ai_service, AskAi)
    case ai_service.ask_with_timeout(request) do
      {:ok, response} ->
        # Clean the response to ensure we only get the name
        name =
          response
          |> String.trim()
          # Remove any additional lines
          |> String.replace(~r/\n.*$/, "")
          # Remove surrounding quotes if any
          |> String.replace(~r/^['"]|['"]$/, "")

        if String.length(name) > 0 do
          {:ok, name}
        else
          {:error, :invalid_ai_response}
        end

      {:error, reason} = error ->
        Logger.error("Failed to get company name from AI: #{inspect(reason)}")
        error
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
