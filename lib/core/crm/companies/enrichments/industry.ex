defmodule Core.Crm.Companies.Enrichments.Industry do
  require Logger
  require OpenTelemetry.Tracer
  alias Core.Ai
  alias Core.Utils.Tracing

  @timeout 60 * 1000
  @model :claude_sonnet
  @max_tokens 250
  @temperature 0.1
  @system_prompt """
  I'm going to provide you metadata about a company, including their website content.
  Your job is to classify the company using the 2022 NAICS (North American Industry Classification System) codes.

  Important rules:
  1. Use ONLY the 2022 NAICS codes. Some codes from previous versions (like 2007 or 2012) have been changed or replaced.
  2. For example, code 511210 from 2012 is now 513210 in 2022.
  3. Choose the most specific and appropriate code that best describes the company's primary business activity.
  4. If multiple codes might apply, choose the one that represents the company's main revenue source or core business.
  5. Return ONLY the code (2-6 digits, e.g. "51" for Information, "513" for Publishing Industries, "5132" for Software Publishers, "51321" for Software Publishers, or "513210" for Software Publishers), nothing else.
  6. DO NOT include any explanation or additional text - just the code.
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

        {:ok, {:error, reason}} ->
          Tracing.error(reason)
          {:error, reason}

        {:exit, reason} ->
          Tracing.error(reason)
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
