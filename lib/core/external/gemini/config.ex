defmodule Core.External.Gemini.Config do
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
        ai_config[:gemini_api_path] ||
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent",
      api_key: ai_config[:gemini_api_key],
      timeout: ai_config[:timeout] || 45_000
    }
  end

  def validate(%__MODULE__{} = config) do
    cond do
      is_nil(config.api_key) or config.api_key == "" ->
        {:error, "Gemini API key is required"}

      is_nil(config.api_path) or config.api_path == "" ->
        {:error, "Gemini API path is required"}

      true ->
        :ok
    end
  end
end
