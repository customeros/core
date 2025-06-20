defmodule Core.Crm.Companies.Enrichment.BusinessModel do
  @moduledoc """
  Module for enriching companies with quantitative information.

  This module uses AI to analyze company website content and identify
  the business model of the company. It includes validation and confidence
  checks to ensure accurate business model identification.
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Core.Ai
  alias Core.Utils.Tracing
  alias Core.Utils.TaskAwaiter

  @timeout 30 * 1000
  @model_gemini :gemini_flash
  @max_tokens 250
  @temperature 0.05
  @system_prompt """
  I'm going to provide you metadata about a company, including their website content.
  Your job is to identify the business model of the company.

  <INSTRUCTIONS>
  1. Return ONLY the business model of the company.
  2. The business model can be one of the following:
    - B2B
    - B2C
    - B2B2C
    - Hybrid
  3. Do not include reasoning in your response.
  4. If you are not sure about the business model, return "null".
  </INSTRUCTIONS>
  """

  def identify_business_model(domain, homepage_content) do
    OpenTelemetry.Tracer.with_span "business_model.identify" do
      prompt = build_prompt(domain, homepage_content)

      request =
        Ai.Request.new(prompt,
          model: @model_gemini,
          system_prompt: @system_prompt,
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

          case response do
            "B2B" -> {:ok, :B2B}
            "B2C" -> {:ok, :B2C}
            "B2B2C" -> {:ok, :B2B2C}
            "Hybrid" -> {:ok, :Hybrid}
            _ -> {:ok, nil}
          end

        {:error, reason} ->
          OpenTelemetry.Tracer.set_attributes([
            {"ai.error.reason", reason}
          ])

          Tracing.error(reason, "Failed to identify business model")
          {:error, reason}
      end
    end
  end

  defp build_prompt(domain, homepage_content) do
    """
    Website: #{domain}

    ---Homepage content---
    #{homepage_content}
    """
  end
end
