defmodule Core.Crm.Contacts.Enricher.LocationAI do
  @moduledoc """
  Module for enriching contact location data using AI analysis.
  Uses Gemini to parse location strings into structured data including
  country, region, city and timezone information.
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Core.Ai
  alias Core.Utils.Tracing
  alias Core.Utils.TaskAwaiter

  @timeout 30 * 1000
  @models [:gemini_flash_2_0, :llama3_70b]
  @max_tokens 100
  @temperature 0.05
  @system_prompt """
  You are a location parsing expert. Your task is to analyze location strings and extract structured location data.

  <INSTRUCTIONS>
  1. Return ONLY a JSON object with the following fields:
     - country_a2: ISO 3166-1 alpha-2 country code (2 letters) or null if uncertain
     - region: Administrative region/state/province or null if uncertain
     - city: City name or null if uncertain
     - timezone: IANA timezone identifier or null if uncertain
  2. Examples of valid responses:
     {"country_a2": "US", "region": "California", "city": "San Francisco", "timezone": "America/Los_Angeles"}
     {"country_a2": "GB", "region": "England", "city": "London", "timezone": "Europe/London"}
  3. If you cannot determine any field with high confidence, set it to null
  4. Always maintain proper JSON format
  5. Do not include any explanations or additional text
  </INSTRUCTIONS>
  """

  @type location_data :: %{
          country_a2: String.t() | nil,
          region: String.t() | nil,
          city: String.t() | nil,
          timezone: String.t() | nil
        }

  @spec parse_location(String.t()) :: {:ok, location_data()} | {:error, term()}
  def parse_location(location) do
    OpenTelemetry.Tracer.with_span "location.parse" do
      prompt = build_prompt(location)
      try_models(prompt, @models, location)
    end
  end

  defp try_models(_prompt, [], _location), do: {:error, :all_models_failed}

  defp try_models(prompt, [model | remaining_models], location) do
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
          {"ai.raw.response", response},
          {"ai.model.used", model}
        ])

        case Jason.decode(response) do
          {:ok, data} ->
            normalized_data = normalize_keys(data)

            Tracing.ok()
            {:ok, normalized_data}

          {:error, reason} ->
            Tracing.error(reason, "Failed to parse AI response as JSON")
            try_models(prompt, remaining_models, location)
        end

      {:error, {:api_error, "User location is not supported for the API use."}} ->
        Logger.warning(
          "Location not supported for model #{model}, trying next model"
        )

        try_models(prompt, remaining_models, location)

      {:error, reason} ->
        Tracing.error(reason, "Failed to get AI response")
        try_models(prompt, remaining_models, location)
    end
  end

  defp build_prompt(location) do
    """
    Parse this location string: #{location}
    """
  end

  defp normalize_keys(map) when is_map(map) do
    map
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
  end
end
