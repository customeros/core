defmodule Core.Researcher.IcpFinder.PromptBuilder do
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
    Your task is to analyze an ICP and generate a list of 20 companies that would be an ideal fit.
    For each company, you must provide:
    - Company name
    - Website domain extracted from the company's website
    - Country a2 code
    - Industry code
    - Industry name

    Classify the company industry using the 2022 NAICS (North American Industry Classification System) codes.

    Important rules:
    1. Use ONLY the 2022 NAICS codes. Some codes from previous versions (like 2007 or 2012) have been changed or replaced.
    2. For example, code 511210 from 2012 is now 513210 in 2022.
    3. Choose the most specific and appropriate code that best describes the company's primary business activity.
    4. If multiple codes might apply, choose the one that represents the company's main revenue source or core business.
    5. Return ONLY the code (2-6 digits, e.g. "51" for Information, "513" for Publishing Industries, "5132" for Software Publishers, "51321" for Software Publishers, or "513210" for Software Publishers), nothing else.
    6. DO NOT include any explanation or additional text - just the code.

    Your response MUST be in valid JSON format exactly matching this schema:
    {
      "companies": [
        {
          "name": "Company Name",
          "domain": "Company Domain",
          "country": "Country a2 code",
          "industry_code": "Industry code",
          "industry": "Industry name"
        }
      ]
    }
    Do not include any text outside the JSON object.
    """

    prompt = """
    Based on the following Ideal Customer Profile (ICP), generate a list of 20 companies that would be an ideal fit.

    ICP Profile:
    #{Jason.encode!(profile.profile, pretty: true)}

    Qualifying Attributes:
    #{Jason.encode!(profile.qualifying_attributes, pretty: true)}
    """

    {system_prompt, prompt}
  end
end
