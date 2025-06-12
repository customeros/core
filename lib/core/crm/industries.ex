defmodule Core.Crm.Industries do
  @moduledoc """
  Manages NAICS (North American Industry Classification System) codes.
  Provides functions for validating and retrieving industry codes and names.
  """

  use Agent
  require Logger
  import Ecto.Query
  alias Core.Repo
  alias Core.Crm.Industries.IndustryMapping
  alias Core.Crm.Industries.Industry

  @agent_name __MODULE__

  def start_link(_opts) do
    Agent.start_link(fn -> load_codes_from_db() end, name: @agent_name)
  end

  @doc """
  Validates if a given NAICS code exists in our database.
  """
  @spec valid_code?(String.t()) :: boolean()
  def valid_code?(code) when is_binary(code) do
    Agent.get(@agent_name, &Map.has_key?(&1, code))
  end

  @doc """
  Retrieves the industry name for a given NAICS code.
  Returns nil if the code is not found.
  """
  @spec get_name(String.t()) :: String.t() | nil
  def get_name(code) when is_binary(code) do
    Agent.get(@agent_name, &Map.get(&1, code))
  end

  @doc """
  Forces a reload of the NAICS codes from the database.
  """
  @spec reload_codes() :: :ok
  def reload_codes do
    Agent.update(@agent_name, fn _state -> load_codes_from_db() end)
  end

  # Loads NAICS codes and names from the database.
  # Returns a map of codes to names.
  @spec load_codes_from_db() :: %{String.t() => String.t()}
  defp load_codes_from_db do
    Logger.info("Loading NAICS codes from database...")

    case Repo.all(
           from industry in Industry, select: {industry.code, industry.name}
         ) do
      [] ->
        Logger.warning("No NAICS codes found in database")
        %{}

      codes ->
        codes_map = Map.new(codes)
        Logger.info("Loaded #{map_size(codes_map)} NAICS codes from database")
        codes_map
    end
  end

  @spec get_by_code(String.t()) :: Industry.t() | nil
  def get_by_code(code) when is_binary(code) do
    code
    |> map_naics_code()
    |> (&Repo.get_by(Industry, code: &1)).()
  end

  def get_by_code(_), do: nil

  @spec create(map()) :: {:ok, Industry.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Industry{}
    |> Industry.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the new NAICS code if the given code is mapped; otherwise returns the code itself.
  """
  @spec map_naics_code(String.t()) :: String.t()
  def map_naics_code(code) when is_binary(code) do
    case get_mapped_industry_code(code) do
      {:ok, mapped_code} -> mapped_code
      {:error, :not_found} -> code
    end
  end

  @spec get_mapped_industry_code(String.t()) ::
          {:ok, String.t()} | {:error, :not_found}
  def get_mapped_industry_code(industry_code) do
    case Repo.get_by(IndustryMapping, code_source: industry_code) do
      nil ->
        {:error, :not_found}

      mapping ->
        {:ok, mapping.code_target}
    end
  end
end
