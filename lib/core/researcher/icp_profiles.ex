defmodule Core.Researcher.IcpProfiles do
  @moduledoc """
  Database operations for ICP profiles.
  """
  require OpenTelemetry.Tracer
  alias Core.Icp.Builder.Profile
  alias Core.Repo
  alias Core.Researcher.IcpProfiles.Profile
  alias Core.Utils.Tracing
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
  @spec get_by_domain(String.t()) ::
          {:ok, Profile.t()} | {:error, :not_found}
  def get_by_domain(domain) when is_binary(domain) do
    case Repo.get_by(Profile, domain: domain) do
      %Profile{} = icp -> {:ok, icp}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Gets a profile by tenant ID.

  Returns the profile struct or nil if not found.
  """
  @spec get_by_tenant_id(String.t()) ::
          {:ok, Profile.t()} | {:error, :not_found}
  def get_by_tenant_id(tenant_id) when is_binary(tenant_id) do
    OpenTelemetry.Tracer.with_span "icp_profiles.get_by_tenant_id" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.id", tenant_id}
      ])

      case Repo.get_by(Profile, tenant_id: tenant_id) do
        %Profile{} = icp ->
          {:ok, icp}

        nil ->
          Tracing.error(:not_found)
          {:error, :not_found}
      end
    end
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
  @spec get_profile(integer()) ::
          {:ok, Profile.t()} | {:error, :not_found}
  def get_profile(id) when is_integer(id) do
    case Repo.get(Profile, id) do
      %Profile{} = icp -> {:ok, icp}
      nil -> {:error, :not_found}
    end
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
      {:error, :not_found} -> {:error, :not_found}
      {:ok, profile} -> update_profile(profile, attrs)
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
      {:error, :not_found} -> {:error, :not_found}
      {:ok, profile} -> delete_profile(profile)
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
