defmodule Core.Researcher.IcpFinder.QueryBuilder do
  @moduledoc """
  Builds queries for finding companies that match an Ideal Customer Profile (ICP).
  """

  alias Core.Repo
  alias Core.Crm.Companies.Company
  alias Core.Researcher.Webpages.ScrapedWebpage

  alias Core.Researcher.IcpFinder.{
    CompaniesQueryInput,
    TopicsAndIndustriesInput
  }

  import Ecto.Query

  @doc """
  Builds a query for finding companies that match an Ideal Customer Profile (ICP).
  """
  def get_industry_and_topic_values(%CompaniesQueryInput{} = input) do
    # Build the top domains subquery
    top_domains_query =
      from c in Company,
        where: c.business_model == ^input.business_model,
        where: ^build_employee_count_condition(input),
        where: c.homepage_scraped == true,
        select: %{domain: fragment("extract_root_domain(?)", c.primary_domain)},
        limit: 200

    # Build the normalized webpages subquery
    normalized_webpages_query =
      from sw in ScrapedWebpage,
        select: %{
          primary_topic: sw.primary_topic,
          industry_vertical: sw.industry_vertical,
          url_domain: fragment("extract_root_domain(?)", sw.url),
          domain_domain: fragment("extract_root_domain(?)", sw.domain)
        }

    # Build the primary topic limited subquery
    primary_topic_limited_query =
      from nw in subquery(normalized_webpages_query),
        join: td in subquery(top_domains_query),
        on: nw.url_domain == td.domain and nw.domain_domain == td.domain,
        where: not is_nil(nw.primary_topic),
        select: %{value: nw.primary_topic, source: "primary_topic"},
        distinct: nw.primary_topic,
        limit: 100

    # Build the industry vertical limited subquery
    industry_vertical_limited_query =
      from nw in subquery(normalized_webpages_query),
        join: td in subquery(top_domains_query),
        on: nw.url_domain == td.domain and nw.domain_domain == td.domain,
        where: not is_nil(nw.industry_vertical),
        select: %{value: nw.industry_vertical, source: "industry_vertical"},
        distinct: nw.industry_vertical,
        limit: 100

    # Execute both queries separately and combine results
    primary_topics = Repo.all(primary_topic_limited_query)
    industry_verticals = Repo.all(industry_vertical_limited_query)

    # Combine the results
    primary_topics ++ industry_verticals
  end

  @doc """
  Finds companies that match the given topics and industries.
  """
  def find_matching_companies(
        %CompaniesQueryInput{} = input,
        %TopicsAndIndustriesInput{} = topics_and_industries
      ) do
    # Build the top domains subquery
    top_domains_query =
      from c in Company,
        where: c.business_model == ^input.business_model,
        where: ^build_employee_count_condition(input),
        where: c.homepage_scraped == true,
        select: %{domain: fragment("extract_root_domain(?)", c.primary_domain)},
        limit: 200

    # Build the normalized webpages subquery
    normalized_webpages_query =
      from sw in ScrapedWebpage,
        select: %{
          primary_topic: sw.primary_topic,
          industry_vertical: sw.industry_vertical,
          url_domain: fragment("extract_root_domain(?)", sw.url),
          domain_domain: fragment("extract_root_domain(?)", sw.domain)
        }

    # Build the matches subquery
    matches_query =
      from nw in subquery(normalized_webpages_query),
        join: td in subquery(top_domains_query),
        on: nw.url_domain == td.domain and nw.domain_domain == td.domain,
        where:
          nw.primary_topic in ^topics_and_industries.topics or
            nw.industry_vertical in ^topics_and_industries.industry_verticals,
        select: %{url_domain: nw.url_domain},
        distinct: nw.url_domain

    # Build the final companies query
    query =
      from c in Company,
        join: m in subquery(matches_query),
        on:
          fragment("extract_root_domain(?)", c.primary_domain) == m.url_domain,
        where: c.business_model == ^input.business_model,
        where: c.homepage_scraped == true,
        where: ^build_employee_count_condition(input),
        select: %{id: c.id, primary_domain: c.primary_domain},
        distinct: c.primary_domain,
        order_by: c.primary_domain,
        limit: 25

    Repo.all(query)
  end

  # Helper function to build the employee count condition dynamically
  defp build_employee_count_condition(input) do
    # Handle nil values
    if is_nil(input.employee_count) or is_nil(input.employee_count_operator) do
      # Return a condition that always evaluates to true (no filtering)
      dynamic([c], true)
    else
      case input.employee_count_operator do
        "=" -> dynamic([c], c.employee_count == ^input.employee_count)
        ">" -> dynamic([c], c.employee_count > ^input.employee_count)
        ">=" -> dynamic([c], c.employee_count >= ^input.employee_count)
        "<" -> dynamic([c], c.employee_count < ^input.employee_count)
        "<=" -> dynamic([c], c.employee_count <= ^input.employee_count)
        "!=" -> dynamic([c], c.employee_count != ^input.employee_count)
        _ -> dynamic([c], c.employee_count == ^input.employee_count)
      end
    end
  end
end
