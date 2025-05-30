defmodule Core.Researcher.IcpFinder do
  @moduledoc """
  Provides functionality to find companies that match ICP profiles using AI.
  """

  alias Core.Ai
  alias Core.Crm.Companies
  alias Core.Crm.Companies.Company
  alias Core.Researcher.IcpProfiles
  alias Core.Researcher.IcpFinder.PromptBuilder

  # 2 mins
  @icp_finder_timeout 2 * 60 * 1000

  @doc """
  Generates a list of 20 ideal companies that match the given ICP profile.

  Returns `{:ok, companies}` on success where companies is a list of maps containing company information,
  or `{:error, reason}` on failure.
  """
  @spec find_matching_companies(integer()) :: {:ok, [map()]} | {:error, term()}
  def find_matching_companies(profile_id) do
    with {:ok, profile} <- IcpProfiles.get_profile(profile_id),
         {:ok, companies} <- generate_matches(profile) do
      {:ok, companies}
    end
  end

  @doc """
  Generates a list of 20 ideal companies that match the given ICP profile using AI.

  Returns `{:ok, companies}` on success where companies is a list of maps containing company information,
  or `{:error, reason}` on failure.
  """
  @spec generate_matches(Core.Researcher.Profiles.Profile.t()) ::
          {:ok, [map()]} | {:error, term()}
  def generate_matches(profile) do
    task =
      profile
      |> PromptBuilder.build_prompts()
      |> PromptBuilder.build_request()
      |> Ai.ask_supervised()

    case Task.yield(task, @icp_finder_timeout) do
      {:ok, {:ok, answer}} ->
        answer
        |> parse_companies()
        |> Enum.map(fn company -> Companies.get_or_create(company) end)

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
        companies |> Enum.map(fn company -> struct(Company, company) end)

      {:ok, _} ->
        {:error, :invalid_response_format}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
