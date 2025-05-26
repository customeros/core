defmodule Core.Crm.Companies.Enrichments.Industry do
  require Logger
  alias Core.Ai

  @system_prompt """
  I'm going to provide you metadata about a company, including their website content.
  Your job is to classify the company using the 2022 NAICS (North American Industry Classification System) codes.

  Important rules:
  1. Use ONLY the 2022 NAICS codes. Some codes from previous versions (like 2007 or 2012) have been changed or replaced.
  2. For example, code 511210 from 2012 is now 513210 in 2022.
  3. Choose the most specific and appropriate code that best describes the company's primary business activity.
  4. If multiple codes might apply, choose the one that represents the company's main revenue source or core business.
  5. Return ONLY the code (2-6 digits, e.g. "51" for Information, "513" for Publishing Industries, "5132" for Software Publishers, "51321" for Software Publishers, or "513210" for Software Publishers), nothing else.
  """

  @type input :: %{
          domain: String.t(),
          homepage_content: String.t()
        }

  @spec identify(input() | nil | map()) :: {:ok, String.t()} | {:error, term()}
  def identify(nil), do: {:error, {:invalid_request, "Input cannot be nil"}}

  def identify(%{domain: domain, homepage_content: content})
      when is_binary(domain) and is_binary(content) do
    prompt = build_prompt(domain, content)

    request = %Ai.Request{
      model: :claude_sonnet,
      prompt: prompt,
      system_prompt: @system_prompt,
      max_output_tokens: 250,
      model_temperature: 0.1
    }

    case Ai.ask_with_timeout(request) do
      {:ok, response} ->
        # Clean the response to ensure we only get the code
        code =
          response
          |> String.trim()
          |> String.replace(~r/[^0-9]/, "")

        if String.length(code) > 0 do
          {:ok, code}
        else
          {:error, :invalid_ai_response}
        end

      {:error, reason} = error ->
        Logger.error("Failed to get industry code from AI: #{inspect(reason)}")
        error
    end
  end

  def identify(_), do: {:error, {:invalid_request, "Invalid input format"}}

  defp build_prompt(domain, content) do
    """
    Website: #{domain}

    ---Homepage content---
    #{content}
    """
  end
end
