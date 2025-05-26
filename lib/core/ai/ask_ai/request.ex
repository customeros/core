defmodule Core.Ai.AskAi.AskAIRequest do
  @derive Jason.Encoder
  @moduledoc """
  Represents a request to ask a question to an AI Model.
  """

  @type model :: :google_gemini_pro | :anthropic_claude_3_sonnet

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
    model_temperature: 0.2
  ]

  @doc """
  Creates a new AskAIRequest struct with the given parameters.

  ## Parameters
    - model: The AI model to use (:google_gemini_pro or :anthropic_claude_3_sonnet)
    - prompt: The prompt to send to the AI
    - opts: Optional parameters (system_prompt, max_output_tokens, model_temperature)

  ## Returns
    - `%AskAIRequest{}` - A new AskAIRequest struct

  ## Examples
      iex> Core.Ai.AskAi.AskAIRequest.new(:claude_sonnet, "Hello")
      %AskAIRequest{model: :anthropic_claude_3_sonnet, prompt: "Hello"}
  """
  @spec new(model(), String.t(), Keyword.t()) :: t()
  def new(model, prompt, opts \\ []) do
    struct!(__MODULE__, [
      model: model,
      prompt: prompt,
      system_prompt: Keyword.get(opts, :system_prompt),
      max_output_tokens: Keyword.get(opts, :max_output_tokens),
      model_temperature: Keyword.get(opts, :model_temperature)
    ])
  end
end
