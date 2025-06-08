defmodule Core.Ai.Groq.Config do
  @moduledoc """
  Module for managing Groq AI API configuration.

  This module handles the configuration settings for the Groq AI API,
  including API path, API key, and timeout settings. It provides functions
  for loading configuration from the application environment and validating
  the configuration settings.
  """

  @type t :: %__MODULE__{
          api_path: String.t(),
          api_key: String.t(),
          timeout: integer()
        }

  defstruct [
    :api_path,
    :api_key,
    ## 45 seconds
    timeout: 45_000
  ]

  def from_application_env do
    ai_config = Application.get_env(:core, :ai)

    %__MODULE__{
      api_path:
        ai_config[:groq_api_path] ||
          "https://api.groq.com/openai/v1/chat/completions",
      api_key: ai_config[:groq_api_key],
      timeout: ai_config[:timeout] || 45_000
    }
  end

  def validate(%__MODULE__{} = config) do
    cond do
      is_nil(config.api_key) or config.api_key == "" ->
        {:error, "Groq API key is required"}

      is_nil(config.api_path) or config.api_path == "" ->
        {:error, "Groq API path is required"}

      true ->
        :ok
    end
  end
end
