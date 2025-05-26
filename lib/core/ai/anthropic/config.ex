defmodule Core.Ai.Anthropic.Config do
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
        ai_config[:anthropic_api_path] ||
          "https://api.anthropic.com/v1/messages",
      api_key: ai_config[:anthropic_api_key],
      timeout: ai_config[:timeout] || 45_000
    }
  end

  def validate(%__MODULE__{} = config) do
    cond do
      is_nil(config.api_key) or config.api_key == "" ->
        {:error, "Anthropic API key is required"}

      is_nil(config.api_path) or config.api_path == "" ->
        {:error, "Anthropic API path is required"}

      true ->
        :ok
    end
  end
end
