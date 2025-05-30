defmodule Core.Researcher.IcpFinder do
  @moduledoc """
  Provides functionality to find companies that match ICP profiles using AI.
  """

  alias Core.Ai
  alias Core.Crm.Leads
  alias Core.Auth.Tenants
  alias Core.Crm.Companies
  alias Core.Crm.Companies.Company
  alias Core.Researcher.IcpProfiles
  alias Core.Researcher.IcpFinder.PromptBuilder

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
  @spec find_matching_companies(integer()) :: {:ok, [map()]} | {:error, term()}
  def find_matching_companies(profile_id) do
    with {:ok, profile} <- IcpProfiles.get_profile(profile_id),
         {:ok, tenant} <- Tenants.get_tenant_by_id(profile.tenant_id),
         {:ok, companies} <- generate_matches(profile, tenant) do
      {:ok, companies}
    end
  end

  @doc """
  Generates a list of 20 ideal companies that match the given ICP profile using AI.

  Returns `{:ok, companies}` on success where companies is a list of maps containing company information,
  or `{:error, reason}` on failure.
  """
  @spec generate_matches(
          Core.Researcher.Profiles.Profile.t(),
          Core.Auth.Tenants.Tenant.t()
        ) ::
          {:ok, [map()]} | {:error, term()}
  def generate_matches(profile, tenant) do
    task =
      profile
      |> PromptBuilder.build_prompts()
      |> PromptBuilder.build_request()
      |> Ai.ask_supervised()

    case Task.yield(task, @icp_finder_timeout) do
      {:ok, {:ok, answer}} ->
        answer
        |> parse_companies()
        |> Enum.filter(fn company -> validate(company) end)
        |> Enum.map(fn company -> Companies.get_or_create(company) end)
        |> Enum.map(fn {:ok, company} ->
          Leads.get_or_create(tenant.name, %{
            ref_id: company.id,
            type: :company,
            stage: :target
          })
        end)

      {:ok, {:error, reason}} ->
        {:error, reason}

      nil ->
        Task.shutdown(task)
        {:error, :ai_timeout}

      {:exit, reason} ->
        {:error, reason}
    end
  end

  defp parse_companies(response) do
    case Jason.decode(response) do
      {:ok, %{"companies" => companies}} when is_list(companies) ->
        companies
        |> Enum.map(&parse_company/1)

      {:ok, _} ->
        {:error, :invalid_response_format}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_company(company) do
    %Company{
      primary_domain: company["primary_domain"],
      name: company["name"],
      industry_code: company["industry_code"],
      industry: company["industry"],
      country_a2: company["country_a2"]
    }
  end

  defp validate(
         %Company{
           primary_domain: _domain,
           name: _name,
           industry_code: _industry_code,
           industry: _industry,
           country_a2: _country_a2
         } = _company
       ) do
    true
  end

  defp validate(_), do: false
end
