defmodule Core.Crm.Companies.Enrichment.Industry do
  @moduledoc """
  Handles company industry classification using AI and NAICS codes.

  This module manages:
  * Industry classification of companies
  * NAICS code identification
  * AI-powered industry analysis
  * Response validation and processing
  * Error handling and tracing

  It uses AI to analyze company website content and classify
  companies according to the 2022 NAICS (North American Industry
  Classification System) codes. The module ensures accurate
  industry classification through strict validation and proper
  error handling.
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Core.Ai
  alias Core.Utils.Tracing

  @timeout 30 * 1000
  @model :gemini_flash
  @max_tokens 20
  @temperature 0.05
  @system_prompt """
  You are an expert in business classification using the North American Industry Classification System (NAICS).
  I will provide you with company metadata and website content.
  Your sole task is to classify the company using ONLY the 2022 NAICS (North American Industry Classification System) codes.

  <INSTRUCTIONS>
  1.  Strictly use the 2022 NAICS CODES. Do NOT use codes from 2017, 2012 or any other previous versions.
  2.  Many codes have changed, merged, or been eliminated in the 2022 revision. For instance, if a 2017 code was 448210 "Shoe Stores", its 2022 equivalent is 458210 "Shoe Retailers". You MUST use the 2022 version.
  3.  Choose the most specific and appropriate 2022 NAICS code (from 2 to 6 digits) that precisely describes the company's primary business activity.
    - Prioritize 6-digit codes if a clear, exact match exists for the specific activity.
    - If a precise 6-digit code does not exist or cannot be confidently determined for the company's specific activity, return the most specific applicable parent code (e.g., a 5-digit, 4-digit, 3-digit, or 2-digit code).
    - A 6-digit code that ends in '0' (like 513210) is valid only if it is the direct 6-digit U.S. industry code for a 5-digit industry that has no further subdivisions. Do not invent a '0' ending 6-digit code for a 5-digit industry that has actual 6-digit subdivisions (e.g., for 55111, the 6-digit codes are 551111, 551112, 551114, not 551110).
  4.  If multiple 2022 codes could apply, select the one that represents the company's main revenue source or core business.
  5.  Valid 2-digit NAICS prefixes for 2022 are: 11, 21, 22, 23, 31, 32, 33, 42, 44, 45, 48, 49, 51, 52, 53, 54, 55, 56, 61, 62, 71, 72, 81, 92.
  6.  Return ONLY the 2022 NAICS code. Do NOT include any explanation, additional text, or conversational remarks. Just the code.
  7.  Do not invent the codes. If you are not 100% sure of the code, return an empty string.
  </INSTRUCTIONS>

  <EXAMPLES>
  - Most specific 6-digit (e.g., with specific subdivisions): 551111 (Offices of Bank Holding Companies)
  - Most specific 6-digit (e.g., where 5-digit adds '0'): 513210 (Software Publishers)
  - Most specific parent code (e.g., if 6-digit is not precise): 55111 (Management of Companies and Enterprises - 5-digit)
  - General 4-digit: 5415 (Computer Systems Design and Related Services)
  </EXAMPLES>
  """

  @type input :: %{
          domain: String.t(),
          homepage_content: String.t()
        }

  @spec identify(input() | nil | map()) :: {:ok, String.t()} | {:error, term()}
  def identify(nil), do: {:error, {:invalid_request, "Input cannot be nil"}}

  def identify(%{domain: domain, homepage_content: content})
      when is_binary(domain) and is_binary(content) do
    OpenTelemetry.Tracer.with_span "industry.identify" do
      prompt = build_prompt(domain, content)

      request =
        Ai.Request.new(prompt,
          model: @model,
          system_prompt: @system_prompt,
          max_tokens: @max_tokens,
          temperature: @temperature
        )

      task = Ai.ask_supervised(request)

      case Task.await(task, @timeout) do
        {:ok, {:ok, response}} ->
          OpenTelemetry.Tracer.set_attributes([
            {"ai.raw.response", response}
          ])

          Tracing.ok()

          process_response(response)

        {:ok, response} when is_binary(response) ->
          OpenTelemetry.Tracer.set_attributes([
            {"ai.raw.response", response}
          ])

          Tracing.ok()

          process_response(response)

        {:ok, {:error, {:http_error, reason}}} ->
          Tracing.error(reason)
          {:error, :http_error}

        {:ok, {:error, reason}} ->
          Tracing.error(reason)
          Logger.error("Failed to identify industry: #{inspect(reason)}")
          {:error, reason}

        {:error, reason} ->
          Tracing.error(reason)
          Logger.error("Failed to identify industry: #{inspect(reason)}")
          {:error, reason}

        {:exit, reason} ->
          Tracing.error(reason)
          Logger.error("Failed to identify industry: #{inspect(reason)}")
          {:error, reason}

        nil ->
          Task.shutdown(task)
          Tracing.error(:ai_timeout)
          {:error, :ai_timeout}
      end
    end
  end

  def identify(_), do: {:error, {:invalid_request, "Invalid input format"}}

  defp process_response(response) do
    code =
      response
      |> String.trim()
      |> String.split("\n")
      |> List.first()
      |> String.replace(~r/[^0-9]/, "")

    if String.length(code) > 0 do
      Tracing.ok()
      {:ok, code}
    else
      Tracing.error(:invalid_ai_response)
      {:error, :invalid_ai_response}
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
