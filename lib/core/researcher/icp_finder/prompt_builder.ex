defmodule Core.Researcher.IcpFinder.PromptBuilder do
  @moduledoc """
  Builds prompts for identifying and discovering potential Ideal Customer Profiles (ICPs).

  This module is responsible for constructing prompts that help in the process of
  identifying and defining new ICPs. It generates structured prompts for AI-based
  analysis to discover and validate potential ICPs based on various business criteria.
  """

  alias Core.Ai
  alias Core.Researcher.IcpFinder.TopicsAndIndustriesInput

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

  def build_companies_filter_values_prompt(profile) do
    system_prompt = """
    You are a PostgreSQL expert.
    You are given a schema for a companies table.
    You are given an Ideal Customer Profile (ICP) and a list of qualifying attributes for a subject company.

    Output a value for business_model that is a strong fit for the ICP.
    Output a value for industry that is a strong fit for the ICP. The value could be a single industry or a list of industries. The value must be valid industry codes from naics_6_code 2022.
    Output a value for country_a2 that is a strong fit for the ICP. The value could be a single country or a list of countries. The value must be valid ISO 3166-1 alpha-2 country codes.
    Output a value for employee_count that is a strong fit for the ICP.
    Output a value for employee_count_operator that is a strong fit for the ICP. The value must be a valid postgresql operator.

    Your response must include valid postgresql values based on the provided table schema. Omit anything else. Return the values in a JSON object with the following keys:
    - business_model
    - industry
    - country_a2
    - employee_count
    - employee_count_operator
    """

    prompt = """
    Based on the following Ideal Customer Profile (ICP), generate a list of 100 companies that would be an ideal fit.

    Table Schemas:
    CREATE TYPE "public"."business_model" AS ENUM ('B2B', 'B2C', 'B2B2C', 'Hybrid');
    CREATE TABLE "public"."companies" (
    "id" varchar(255) NOT NULL,
    "primary_domain" varchar(255) NOT NULL,
    "name" varchar(1000),
    "industry" varchar(255),
    "country_a2" varchar(255),
    "city" varchar(255),
    "region" varchar(255),
    "business_model" "public"."business_model",
    "employee_count" int4,
    PRIMARY KEY ("id")
    );

    Ideal Customer Profile (ICP):
    #{Jason.encode!(profile.profile, pretty: true)}

    Qualifying Attributes:
    #{Jason.encode!(profile.qualifying_attributes, pretty: true)}
    """

    {system_prompt, prompt}
  end

  def build_scraped_webpages_distinct_data_prompt(
        profile,
        %TopicsAndIndustriesInput{} = topics_and_industries
      ) do
    system_prompt = """
    You are an expert at identifying topics and industry verticals that are a strong fit for an Ideal Customer Profile (ICP).
    Your task is to analyze an ICP and choose from the provided list of topics and industry verticals 25 topics and 25 industry verticals that are a strong fit.

    The topics and industry verticals must be distinct and not the same.

    The output format must be a JSON object with the following keys:
    - topics
    - industry_verticals

    If the given list of topics is empty, output an empty list for topics.
    If the given list of industry verticals is empty, output an empty list for industry_verticals.

    Your response must include valid JSON. Omit anything else.
    """

    prompt = """
    Based on the ICP, the quality attributes and considering the list of topics and industry verticals, output the 25 most fit topics and 25 most fit industry verticals.

    Ideal Customer Profile (ICP):
    #{Jason.encode!(profile.profile, pretty: true)}

    Quality attributes:
    #{Jason.encode!(profile.qualifying_attributes, pretty: true)}

    List of topics:
    #{Jason.encode!(topics_and_industries.topics, pretty: true)}

    List of industry verticals:
    #{Jason.encode!(topics_and_industries.industry_verticals, pretty: true)}
    """

    {system_prompt, prompt}
  end
end
