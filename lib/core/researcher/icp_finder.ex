defmodule Core.Researcher.IcpFinder do
  @moduledoc """
  Provides functionality to find companies that match ICP profiles using AI.
  """
  alias Core.Ai
  alias Core.Crm.Leads
  alias Core.Auth.Tenants
  alias Core.Crm.Companies
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
    task =
      profile
      |> PromptBuilder.build_prompts()
      |> PromptBuilder.build_request()
      |> Ai.ask_supervised()

    case Task.yield(task, @icp_finder_timeout) do
      {:ok, {:ok, answer}} ->
        with {:ok, companies} <- parse_companies(answer),
             created_companies <-
               Enum.map(companies, fn company ->
                 Companies.get_or_create_by_domain(company)
               end),
             leads <-
               Enum.map(created_companies, fn {:ok, company} ->
                 Leads.get_or_create(tenant.name, %{
                   ref_id: company.id,
                   type: :company
                 })
               end) do
          {:ok, leads}
        else
          {:error, reason} -> {:error, reason}
        end

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
        parsed_companies = Enum.map(companies, &parse_company/1)
        {:ok, parsed_companies}

      {:ok, _} ->
        {:error, :invalid_response_format}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_company(company) do
    company["domain"]
  end
end
