defmodule Core.External.Gemini.Config do
  @moduledoc """
  Configuration for the Gemini API service.
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

  @behaviour Access

  @impl Access
  def fetch(config, key) do
    Map.fetch(config, key)
  end

  @impl Access
  def get_and_update(config, key, fun) do
    Map.get_and_update(config, key, fun)
  end

  @impl Access
  def pop(config, key) do
    Map.pop(config, key)
  end

  def from_application_env do
    %__MODULE__{
      api_key: Application.get_env(:core, :gemini_api_key, "test-key"),
      api_path: Application.get_env(:core, :gemini_api_path, "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent"),
      timeout: Application.get_env(:core, :gemini_timeout, 45_000)
    }
  end

  defp get_config_value(config, key, default \\ nil) do
    case config do
      config when is_map(config) -> Map.get(config, key, default)
      config when is_list(config) -> Keyword.get(config, key, default)
      _ -> default
    end
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
