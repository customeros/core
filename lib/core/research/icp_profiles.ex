defmodule Core.Research.IcpProfiles do
  @moduledoc """
  Database operations for ICP profiles.
  """

  alias Core.Repo
  alias Core.Research.Profiles.Profile
  import Ecto.Query

  ## Create ##

  @doc """
  Creates a new ICP profile.

  Returns `{:ok, profile}` on success or `{:error, changeset}` on validation failure.
  """
  @spec create_profile(map()) ::
          {:ok, Profile.t()} | {:error, Ecto.Changeset.t()}
  def create_profile(attrs) do
    %Profile{}
    |> Profile.changeset(attrs)
    |> Repo.insert()
  end

  ## Get ##

  @doc """
  Gets a profile by domain.

  Returns the profile struct or nil if not found.
  """
  @spec get_by_domain(String.t()) :: Profile.t() | nil
  def get_by_domain(domain) when is_binary(domain) do
    Repo.get_by(Profile, domain: domain)
  end

  @doc """
  Gets a profile by tenant ID.

  Returns the profile struct or nil if not found.
  """
  @spec get_by_tenant_id(String.t()) :: Profile.t() | nil
  def get_by_tenant_id(tenant_id) when is_binary(tenant_id) do
    Repo.get_by(Profile, tenant_id: tenant_id)
  end

  @doc """
  Gets all profiles for a tenant ID.

  Returns a list of profiles (empty list if none found).
  """
  @spec list_by_tenant_id(String.t()) :: [Profile.t()]
  def list_by_tenant_id(tenant_id) when is_binary(tenant_id) do
    from(p in Profile, where: p.tenant_id == ^tenant_id)
    |> Repo.all()
  end

  @doc """
  Gets a profile by ID.
  """
  @spec get_profile(integer()) :: Profile.t() | nil
  def get_profile(id) when is_integer(id) do
    Repo.get(Profile, id)
  end

  ## Update ##

  @doc """
  Updates an existing profile.
  """
  @spec update_profile(Profile.t(), map()) ::
          {:ok, Profile.t()} | {:error, Ecto.Changeset.t()}
  def update_profile(%Profile{} = profile, attrs) do
    profile
    |> Profile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a profile by domain.

  Returns `{:ok, profile}` on success, `{:error, :not_found}` if profile doesn't exist,
  or `{:error, changeset}` on validation failure.
  """
  @spec update_by_domain(String.t(), map()) ::
          {:ok, Profile.t()}
          | {:error, :not_found}
          | {:error, Ecto.Changeset.t()}
  def update_by_domain(domain, attrs) do
    case get_by_domain(domain) do
      nil -> {:error, :not_found}
      profile -> update_profile(profile, attrs)
    end
  end

  ## Delete ##

  @doc """
  Deletes a profile.
  """
  @spec delete_profile(Profile.t()) ::
          {:ok, Profile.t()} | {:error, Ecto.Changeset.t()}
  def delete_profile(%Profile{} = profile) do
    Repo.delete(profile)
  end

  @doc """
  Deletes a profile by domain.

  Returns `{:ok, profile}` on success or `{:error, :not_found}` if not found.
  """
  @spec delete_by_domain(String.t()) ::
          {:ok, Profile.t()} | {:error, :not_found}
  def delete_by_domain(domain) do
    case get_by_domain(domain) do
      nil -> {:error, :not_found}
      profile -> delete_profile(profile)
    end
  end

  ## List/Query ##

  @doc """
  Lists all profiles.
  """
  @spec list_all_profiles() :: [Profile.t()]
  def list_all_profiles do
    Repo.all(Profile)
  end

  ## Existence Checks ##

  @doc """
  Checks if a profile exists for the given domain.
  """
  @spec exists_by_domain?(String.t()) :: boolean()
  def exists_by_domain?(domain) when is_binary(domain) do
    from(p in Profile, where: p.domain == ^domain, select: 1)
    |> Repo.exists?()
  end

  @doc """
  Checks if a profile exists for the given tenant ID.
  """
  @spec exists_by_tenant_id?(String.t()) :: boolean()
  def exists_by_tenant_id?(tenant_id) when is_binary(tenant_id) do
    from(p in Profile, where: p.tenant_id == ^tenant_id, select: 1)
    |> Repo.exists?()
  end
end
