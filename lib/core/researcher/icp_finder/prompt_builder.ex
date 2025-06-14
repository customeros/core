defmodule Core.Researcher.IcpFinder.PromptBuilder do
  @moduledoc """
  Builds prompts for identifying and discovering potential Ideal Customer Profiles (ICPs).

  This module is responsible for constructing prompts that help in the process of
  identifying and defining new ICPs. It generates structured prompts for AI-based
  analysis to discover and validate potential ICPs based on various business criteria.
  """

  alias Core.Ai
  @model :claude_sonnet
  @model_temperature 0.2
  @max_tokens 2000

  def build_request({system_prompt, prompt}) do
    %Ai.Request{
      model: @model,
      prompt: prompt,
      system_prompt: system_prompt,
      max_output_tokens: @max_tokens,
      model_temperature: @model_temperature
    }
  end

  def build_prompts(profile) do
    system_prompt = """
    You are an expert at identifying companies that match Ideal Customer Profiles (ICPs).
    Your task is to analyze an ICP and generate a list of 100 companies that would be an ideal fit.
    For each company, you must provide:
    - Website domain extracted from the company's website

    Make sure you do not include any companies that are competitors of the ICP.  If a company is a competitor, ignore it and produce another one.

    Your response MUST be in valid JSON format exactly matching this schema:
    {
      "companies": [
        {
          "domain": "google.com"
        }
      ]
    }
    Do not include any text outside the JSON object.
    """

    prompt = """
    Based on the following Ideal Customer Profile (ICP), generate a list of 100 companies that would be an ideal fit.

    ICP Profile:
    #{Jason.encode!(profile.profile, pretty: true)}

    Qualifying Attributes:
    #{Jason.encode!(profile.qualifying_attributes, pretty: true)}
    """

    {system_prompt, prompt}
  end
end
