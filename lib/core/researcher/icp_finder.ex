defmodule Core.Researcher.IcpFinder do
  @moduledoc """
  Provides functionality to find companies that match ICP profiles using AI.
  """
  alias Core.Ai
  alias Core.Crm.Leads
  alias Core.Auth.Tenants
  alias Core.Utils.TaskAwaiter
  alias Core.Researcher.IcpProfiles
  alias Core.Researcher.IcpFinder.PromptBuilder
  alias Core.Researcher.IcpFinder.CompaniesQueryInput
  alias Core.Researcher.IcpFinder.QueryBuilder
  alias Core.Researcher.IcpFinder.TopicsAndIndustriesInput

  # 2 mins
  @icp_finder_timeout 2 * 60 * 1000

  @doc """
  Starts a task to find matching companies for a tenant.
  Returns `:ok` on success, or `{:error, reason}` on failure.
  """
  def find_matching_companies_start(tenant_id) do
    Task.Supervisor.start_child(
      Core.TaskSupervisor,
      fn ->
        find_matching_companies(tenant_id)
      end
    )
  end

  @doc """
  Generates a list of 20 ideal companies that match the given ICP profile.
  Returns `{:ok, companies}` on success where companies is a list of maps containing company information,
  or `{:error, reason}` on failure.
  """
  def find_matching_companies(profile_id) do
    with {:ok, profile} <- IcpProfiles.get_profile(profile_id),
         {:ok, tenant} <- Tenants.get_tenant_by_id(profile.tenant_id),
         {:ok, companies} <- generate_matches(profile, tenant) do
      {:ok, companies}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates a list of 20 ideal companies that match the given ICP profile using AI.
  Returns `{:ok, companies}` on success where companies is a list of maps containing company information,
  or `{:error, reason}` on failure.
  """
  def generate_matches(
        %IcpProfiles.Profile{} = profile,
        %Tenants.Tenant{} = tenant
      ) do
    with {:ok, input} <- get_companies_filter_values(profile),
         {:ok, topics_and_industries} <-
           get_topics_and_industries(input),
         {:ok, selected_topics_and_industries} <-
           get_selected_topics_and_industries(topics_and_industries, profile) do
      create_leads_from_companies(
        selected_topics_and_industries,
        input,
        tenant
      )
    end
  end

  defp get_companies_filter_values(profile) do
    task =
      profile
      |> PromptBuilder.build_companies_filter_values_prompt()
      |> PromptBuilder.build_request()
      |> Ai.ask_supervised()

    with {:ok, answer} <- TaskAwaiter.await(task, @icp_finder_timeout) do
      parse_answear(answer)
    end
  end

  defp get_topics_and_industries(input) do
    result = QueryBuilder.get_industry_and_topic_values(input)
    parse_topics_and_industries_answear(result)
  end

  defp get_selected_topics_and_industries(topics_and_industries, profile) do
    task =
      profile
      |> PromptBuilder.build_scraped_webpages_distinct_data_prompt(
        topics_and_industries
      )
      |> PromptBuilder.build_request()
      |> Ai.ask_supervised()

    with {:ok, answer} <- TaskAwaiter.await(task, @icp_finder_timeout) do
      parse_topics_and_industries_selection(answer)
    end
  end

  defp create_leads_from_companies(
         selected_topics_and_industries,
         input,
         tenant
       ) do
    companies =
      QueryBuilder.find_matching_companies(
        input,
        selected_topics_and_industries
      )

    leads =
      Enum.map(companies, fn %{id: id, primary_domain: _} ->
        case Leads.get_or_create(tenant.name, %{ref_id: id, type: :company}) do
          {:ok, lead} -> lead
          {:error, reason} -> {:error, reason}
        end
      end)

    {:ok, leads}
  end

  defp parse_answear(answer) do
    case Jason.decode(answer) do
      {:ok,
       %{
         "business_model" => business_model,
         "industry" => industry,
         "country_a2" => country_a2,
         "employee_count" => employee_count,
         "employee_count_operator" => employee_count_operator
       }} ->
        {:ok,
         %CompaniesQueryInput{
           business_model: String.to_atom(business_model),
           industry: industry,
           country_a2: country_a2,
           employee_count: employee_count,
           employee_count_operator: employee_count_operator
         }}

      {:ok, _} ->
        {:error, :invalid_response_format}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_topics_and_industries_answear(values) when is_list(values) do
    {:ok,
     Enum.reduce(values, %TopicsAndIndustriesInput{}, fn value, acc ->
       case value do
         %{source: "primary_topic"} ->
           Map.put(acc, :topics, [value.value | acc.topics] |> Enum.uniq())

         %{source: "industry_vertical"} ->
           Map.put(
             acc,
             :industry_verticals,
             [value.value | acc.industry_verticals] |> Enum.uniq()
           )

         _ ->
           acc
       end
     end)}
  end

  defp parse_topics_and_industries_answear(_) do
    {:error, :invalid_response_format}
  end

  defp parse_topics_and_industries_selection(answer) do
    case Jason.decode(answer) do
      {:ok, %{"topics" => topics, "industry_verticals" => industry_verticals}} ->
        {:ok,
         %TopicsAndIndustriesInput{
           topics: topics,
           industry_verticals: industry_verticals
         }}

      {:ok, _} ->
        {:error, :invalid_response_format}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
