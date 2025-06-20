defmodule Core.Crm.Companies.Enrichment.Name do
  @moduledoc """
  Module for enriching company names using AI analysis.

  This module uses AI to analyze company website content and identify
  the commonly recognized brand name of a company. It includes validation
  rules to ensure the extracted names meet business requirements.
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Core.Ai
  alias Core.Utils.Tracing
  alias Core.Utils.TaskAwaiter

  @timeout 30 * 1000
  @model_gemini :gemini_flash
  @model_groq :llama3_70b
  @max_tokens 250
  @temperature 0.05
  @system_prompt """
  I'm going to provide you metadata about a company, including their website content.
  Your job is to identify the commonly recognized brand name of the company.

  <INSTRUCTIONS>
  1. Return ONLY the commonly recognized brand name, nothing else.
  2. If the company is more commonly known by a brand name (e.g., "Apple" instead of "Apple Inc."), use that simpler name.
  3. Remove all suffixes like Inc, Ltd, LLC, Corp, etc.
  4. Use title case EXCEPT when:
     - The brand is officially spelled in uppercase (e.g., "UPS", "HSBC")
     - The brand officially starts with lowercase (e.g., "eBay", "iPhone")
  5. Focus on the most recognizable, consumer-facing name.
  6. Do not include reasoning in your response.
  </INSTRUCTIONS>
  """

  @type input :: %{
          domain: String.t(),
          homepage_content: String.t()
        }

  @spec identify(input()) ::
          {:ok, String.t()} | {:error, term()} | {:error, term(), String.t()}
  def identify(%{domain: _domain, homepage_content: _content} = input) do
    OpenTelemetry.Tracer.with_span "name.identify" do
      case identify(input, @model_gemini) do
        {:ok, name} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.name", name},
            {"result.model", @model_gemini}
          ])

          {:ok, name}

        {:error, _reason} ->
          case identify(input, @model_groq) do
            {:ok, name} ->
              OpenTelemetry.Tracer.set_attributes([
                {"result", name},
                {"result.model", @model_groq}
              ])

              {:ok, name}

            {:error, reason} ->
              {:error, reason}
          end
      end
    end
  end

  defp identify(%{domain: domain, homepage_content: content}, model) do
    OpenTelemetry.Tracer.with_span "name.identify" do
      prompt = build_prompt(domain, content)

      request =
        Ai.Request.new(prompt,
          model: model,
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

          name =
            response
            |> String.trim()
            # Remove any additional lines
            |> String.replace(~r/\n.*$/, "")
            # Remove surrounding quotes if any
            |> String.replace(~r/^["']|["']$/, "")
            # Remove any HTML tags
            |> String.replace(~r/<[^>]*>/, "")
            # Remove any URLs
            |> String.replace(~r/https?:\/\/[^\s]+/, "")
            # Remove any email addresses
            |> String.replace(
              ~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/,
              ""
            )
            # Remove any special characters except allowed ones
            |> String.replace(~r/[^a-zA-Z0-9\s\-&.,'()]/, "")
            # Remove multiple spaces
            |> String.replace(~r/\s+/, " ")
            |> String.trim()

          case validate_company_name(name) do
            {:ok, name} ->
              OpenTelemetry.Tracer.set_attributes([
                {"result.name", name}
              ])

              {:ok, name}

            {:error, reason} ->
              Tracing.error(reason)
              {:error, reason}
          end

        {:error, reason} ->
          Tracing.error(reason, "Failed to identify name")
          {:error, reason}
      end
    end
  end

  defp validate_company_name(name) do
    cond do
      # Check for empty or whitespace-only names
      String.trim(name) == "" ->
        {:error, :name_empty}

      # Check minimum length (at least 2 characters)
      String.length(String.trim(name)) < 2 ->
        {:error, :name_too_short}

      # Check maximum length (reasonable company name length)
      String.length(name) > 100 ->
        {:error, :name_too_long}

      # Check for names that are just numbers or special characters
      String.match?(name, ~r/^[\d\s\-&.,'()]+$/) ->
        {:error, :invalid_name_format}

      # Check for names that are too generic
      String.match?(
        name,
        ~r/^(?:company|business|enterprise|organization|corporation)$/i
      ) ->
        {:error, :too_generic}

      # Name looks valid
      true ->
        {:ok, String.trim(name)}
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
