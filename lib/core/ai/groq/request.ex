defmodule Core.Ai.Groq.Request do
  @moduledoc """
  Represents a request to ask a question to Groq AI.
  """
  
  @type model ::
          :llama3_70b
          | :llama3_8b
          | :llama33_70b
          | :llama31_8b
          | :gemma2_9b
          | :llama4_scout
          | :llama4_maverick
          | :qwen_qwq32b
          
  @type t :: %__MODULE__{
          model: model(),
          prompt: String.t(),
          system_prompt: String.t() | nil,
          max_output_tokens: integer() | nil,
          model_temperature: float() | nil
        }
        
  defstruct [
    :model,
    :prompt,
    :system_prompt,
    max_output_tokens: 1024,
    model_temperature: 0.7
  ]

  defimpl Jason.Encoder do
    def encode(request, opts) do
      request
      |> Map.from_struct()
      |> Jason.Encode.map(opts)
    end
  end

  @doc """
  Validates the request and returns errors if any.
  """
  def validate(%__MODULE__{} = request) do
    cond do
      request.model not in [
        :llama3_70b,
        :llama3_8b,
        :llama33_70b,
        :llama31_8b,
        :gemma2_9b,
        :llama4_scout,
        :llama4_maverick,
        :qwen_qwq32b
      ] ->
        {:error, "invalid groq model"}
      is_nil(request.prompt) or request.prompt == "" ->
        {:error, "prompt cannot be empty"}
      true ->
        :ok
    end
  end
end
