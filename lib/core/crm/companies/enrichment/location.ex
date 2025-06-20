defmodule Core.Crm.Companies.Enrichment.Location do
  @moduledoc """
  Module for enriching company location data using AI analysis.

  This module uses AI to analyze company website content and identify
  the company's primary country of operation using ISO 3166-1 alpha-2
  country codes. It includes validation and confidence checks to ensure
  accurate country identification.
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Core.Ai
  alias Core.Utils.Tracing
  alias Core.Utils.TaskAwaiter

  @timeout 30 * 1000
  @model :gemini_flash
  @max_tokens 20
  @temperature 0.05
  @system_prompt_country """
  I'm going to provide you metadata about a company, including their website content.
  Your job is to identify the company's primary country of operation using ISO 3166-1 alpha-2 country codes.

  <INSTRUCTIONS>
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
     - Website extension
  </INSTRUCTIONS>
  """

  @type input :: %{
          domain: String.t(),
          homepage_content: String.t()
        }

  @spec identify_country_code_a2(input()) ::
          {:ok, String.t()} | {:error, term()}
  def identify_country_code_a2(%{domain: domain, homepage_content: content}) do
    OpenTelemetry.Tracer.with_span "country.identify" do
      prompt = build_prompt(domain, content)

      request =
        Ai.Request.new(prompt,
          model: @model,
          system_prompt: @system_prompt_country,
          max_tokens: @max_tokens,
          temperature: @temperature
        )

      task = Ai.ask_supervised(request)

      case TaskAwaiter.await(task, @timeout) do
        {:ok, response} ->
          OpenTelemetry.Tracer.set_attributes([
            {"ai.raw.response", response}
          ])

          Tracing.ok()

          code =
            response
            |> String.trim()
            |> String.upcase()

          if String.length(code) == 2 do
            {:ok, code}
          else
            {:ok, ""}
          end

        {:error, reason} ->
          Tracing.error(reason, "Failed to identify country")
          {:error, reason}
      end
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
