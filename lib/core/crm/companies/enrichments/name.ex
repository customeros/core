defmodule Core.Crm.Companies.Enrichments.Name do
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
  Your job is to identify the commonly recognized brand name of the company.

  Important rules:
  1. Return ONLY the commonly recognized brand name, nothing else.
  2. If the company is more commonly known by a brand name (e.g., "Apple" instead of "Apple Inc."), use that simpler name.
  3. Remove all suffixes like Inc, Ltd, LLC, Corp, etc.
  4. Use title case EXCEPT when:
     - The brand is officially spelled in uppercase (e.g., "UPS", "HSBC")
     - The brand officially starts with lowercase (e.g., "eBay", "iPhone")
  5. Focus on the most recognizable, consumer-facing name.
  6. Do not include reasoning in your response.
  """

  @type input :: %{
          domain: String.t(),
          homepage_content: String.t()
        }

  @spec identify(input()) :: {:ok, String.t()} | {:error, term()}
  def identify(%{domain: domain, homepage_content: content}) do
    OpenTelemetry.Tracer.with_span "name.identify" do
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

          case validate_name(name) do
            {:ok, name} ->
              OpenTelemetry.Tracer.set_attributes([
                {"ai.name", name}
              ])

              Tracing.ok()
              {:ok, name}

            {:error, reason} ->
              Tracing.error(reason)
              {:error, reason}
          end

        {:ok, {:error, reason}} ->
          Tracing.error(reason)
          {:error, reason}

        {:exit, reason} ->
          Tracing.error(reason)
          {:error, reason}

        nil ->
          Task.shutdown(task)
          {:error, :ai_timeout}
      end
    end
  end

  # Validates a company name according to business rules
  defp validate_name(name) do
    cond do
      # Check minimum length (at least 2 characters)
      String.length(name) < 2 ->
        {:error, :name_too_short}

      # Check maximum length (reasonable company name length)
      String.length(name) > 100 ->
        {:error, :name_too_long}

      # Check for common invalid patterns
      String.match?(name, ~r/^(?:the|a|an)\s/i) ->
        {:error, :invalid_name_prefix}

      # Check for names that are just numbers or special characters
      String.match?(name, ~r/^[\d\s\-&.,'()]+$/) ->
        {:error, :invalid_name_format}

      # Check for names that are too generic
      String.match?(
        name,
        ~r/^(?:company|business|enterprise|organization|corporation)$/i
      ) ->
        {:error, :too_generic}

      # Check for names that are just the domain
      String.match?(name, ~r/^[a-z0-9\-]+\.(?:com|org|net|io|co|ai)$/i) ->
        {:error, :domain_as_name}

      # Name looks valid
      true ->
        {:ok, name}
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
