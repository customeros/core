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
  alias Core.Crm.Industries

  @max_retries 5

  @timeout 30 * 1000
  @model :gemini_flash
  @max_tokens 20
  @temperature 0.05
  @system_prompt """
    You are an expert in business classification using the North American Industry Classification System (NAICS).

    You will receive a company website URL and scraped content from that site.

    Your task is to classify the company's **primary business activity** using the **2022 NAICS codes only**.

    <INSTRUCTIONS>
    1. Use strictly the 2022 NAICS codes. Never use codes from older versions like 2012 or 2017.
    2. Many older codes have been deleted or replaced. For example:
      - ❌ Do NOT use `532220` (Formal Wear and Costume Rental) — this code was eliminated in the 2022 update.
    3. Select the **most specific and appropriate** NAICS code that reflects the company's **main revenue-generating activity**.
      - Use a 6-digit code if available.
      - If no precise 6-digit match exists, return the nearest valid 5-digit or 4-digit parent code.
    4. Do NOT guess. If the primary activity is unclear or ambiguous, return an empty string.
    5. Return ONLY the valid 2022 NAICS code — no explanation, no commentary, no punctuation.
    6. If unsure or content is ambiguous, return an empty string.
    7. Do NOT return invented or invalid codes like 532290. All returned codes must be listed in the official 2022 NAICS classification. If unsure, return an empty string.
    8. Just because a code "looks" valid (e.g., 532290) does not mean it is. Cross-check with 2022 codes only.
    </INSTRUCTIONS>

    <EXAMPLES>
      - Valid: 532210
      - Valid: 458110
      - Invalid: 532290 (not a valid 2022 NAICS code)
      - Invalid: "The code is 5415." (no text allowed)
      - Invalid: 532220 (deprecated)
    </EXAMPLES>
  """

  @type input :: %{
          domain: String.t(),
          homepage_content: String.t()
        }

  @spec identify(input() | nil | map()) :: {:ok, String.t()} | {:error, term()}
  def identify(nil), do: {:error, {:invalid_request, "Input cannot be nil"}}
  def identify(input) when is_map(input), do: identify(input, [], @max_retries)
  def identify(_), do: {:error, {:invalid_request, "Invalid input format"}}

  @spec identify(input(), [String.t()], non_neg_integer()) ::
          {:ok, String.t()} | {:error, term()}
  defp identify(_input, _blacklist, 0) do
    Tracing.error(
      :max_attempts_exceeded,
      "Maximum retry attempts exceeded for industry identification"
    )

    {:error, :max_attempts_exceeded}
  end

  defp identify(
         %{domain: domain, homepage_content: content} = input,
         blacklist,
         retries_left
       )
       when is_binary(domain) and is_binary(content) do
    OpenTelemetry.Tracer.with_span "industry.identify.retry" do
      OpenTelemetry.Tracer.set_attributes([
        {"retry.attempt", @max_retries - retries_left + 1},
        {"retry.blacklist", Enum.join(blacklist, ", ")},
        {"retry.remaining", retries_left}
      ])

      prompt = build_prompt(domain, content, blacklist)

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
            {"ai.response", response}
          ])

          code = extract_code(response)

          cond do
            code == "" ->
              Logger.info("Empty code received from AI")
              {:error, :empty_ai_response}

            not Industries.valid_code?(code) ->
              Logger.info(
                "Invalid code received: #{code}, adding to blacklist and retrying..."
              )

              identify(input, [code | blacklist], retries_left - 1)

            true ->
              Tracing.ok()
              {:ok, code}
          end

        {:ok, response} when is_binary(response) ->
          OpenTelemetry.Tracer.set_attributes([
            {"ai.raw.response", response}
          ])

          code = extract_code(response)

          cond do
            code == "" ->
              Logger.info("Empty code received from AI")
              {:error, :empty_ai_response}

            not Industries.valid_code?(code) ->
              Logger.info(
                "Invalid code received: #{code}, adding to blacklist and retrying..."
              )

              identify(input, [code | blacklist], retries_left - 1)

            true ->
              Tracing.ok()
              {:ok, code}
          end

        {:ok, {:error, {:http_error, reason}}} ->
          Tracing.error(reason)
          {:error, :http_error}

        {:ok, {:error, reason}} ->
          Tracing.error(reason, "Failed to identify industry")
          {:error, reason}

        {:error, reason} ->
          Tracing.error(reason, "Failed to identify industry")
          {:error, reason}

        {:exit, reason} ->
          Tracing.error(reason, "Failed to identify industry")
          {:error, reason}

        nil ->
          Task.shutdown(task)
          Tracing.error(:ai_timeout)
          {:error, :ai_timeout}
      end
    end
  end

  defp extract_code(response) do
    response
    |> String.trim()
    |> String.split("\n")
    |> List.first()
    |> String.replace(~r/[^0-9]/, "")
  end

  defp build_prompt(domain, content, []), do: build_prompt(domain, content, nil)

  defp build_prompt(domain, content, blacklist) do
    blacklist_block =
      if is_list(blacklist) and blacklist != [] do
        "\nDo NOT return any of the following invalid codes: " <>
          Enum.join(Enum.uniq(blacklist), ", ") <> "."
      else
        ""
      end

    """
    Website: #{domain}

    ---Homepage content---
    #{content}
    ---End of homepage content---
    #{blacklist_block}
    """
  end
end
