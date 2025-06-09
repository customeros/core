defmodule Core.Crm.Industries do
  @moduledoc """
  Context module for managing industries in the CRM system.

  Provides functions for retrieving and creating industry records.
  Industries are used to categorize and organize CRM entities.
  """

  @valid_codes load_codes()

  alias Core.Crm.Industries.IndustryMapping
  alias Core.Repo
  alias Core.Crm.Industries.Industry

  @doc """
  Loads industry codes from the database at compile time.
  Returns a map of code -> name for quick lookups.
  """
  defp load_codes do
    # Ensure the application and its dependencies are started
    Application.ensure_all_started(:core)
    Application.ensure_all_started(:ecto_sql)
    Application.ensure_all_started(:postgrex)

    # Start the repo if it's not already started
    {:ok, _} = Application.ensure_all_started(:core)
    {:ok, _} = Repo.__adapter__.ensure_all_started(Repo, :temporary)

    # Query all industry codes from the database
    case Repo.all(from i in Industry, select: {i.code, i.name}) do
      codes when is_list(codes) ->
        Map.new(codes)

      _ ->
        require Logger
        Logger.error("Failed to load industry codes from database")
        %{}
    end
  end

  @doc """
  Returns true if the given code is a valid NAICS code.
  """
  @spec valid_code?(String.t()) :: boolean()
  def valid_code?(code) when is_binary(code) do
    Map.has_key?(@valid_codes, code)
  end

  @doc """
  Returns the name for a given NAICS code, or nil if not found.
  """
  @spec get_name(String.t()) :: String.t() | nil
  def get_name(code) when is_binary(code) do
    Map.get(@valid_codes, code)
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
