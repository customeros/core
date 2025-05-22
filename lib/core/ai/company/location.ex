defmodule Core.AI.Company.Location do
  require Logger
  alias Core.Ai.AskAi
  alias Core.Ai.AskAi.AskAIRequest

  @system_prompt_country """
  I'm going to provide you metadata about a company, including their website content.
  Your job is to identify the company's primary country of operation using ISO 3166-1 alpha-2 country codes.

  Important rules:
  1. Return ONLY the ISO 3166-1 alpha-2 country code (2 letters), nothing else.
  2. Examples of valid codes: "US" for United States, "GB" for United Kingdom, "DE" for Germany.
  3. If you cannot determine the country with high confidence, return "XX".
  4. Focus on the company's primary country of operation, not where they might have offices or customers.
  5. Look for clear indicators like:
     - Company headquarters location
     - Legal entity information
     - Contact addresses
     - Domain registration country
     - Language and currency used
  """

  @type input :: %{
    domain: String.t(),
    homepage_content: String.t()
  }

  @spec identifyCountryCodeA2(input()) :: {:ok, String.t()} | {:error, term()}
  def identifyCountryCodeA2(%{domain: domain, homepage_content: content}) do
    prompt = build_prompt(domain, content)

    request = %AskAIRequest{
      model: :claude_sonnet,
      prompt: prompt,
      system_prompt: @system_prompt_country,
      max_output_tokens: 250,
      model_temperature: 0.1
    }

    case AskAi.ask(request) do
      {:ok, response} ->
        # Clean and validate the response
        code = response
        |> String.trim()
        |> String.upcase()
        |> String.replace(~r/[^A-Z]/, "") # Remove any non-letters

        if String.length(code) == 2 do
          {:ok, code}
        else
          # If we couldn't get a valid 2-letter code, return empty string
          {:ok, ""}
        end

      {:error, reason} = error ->
        Logger.error("Failed to get country code from AI: #{inspect(reason)}")
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
