defmodule Core.Auth.PersonalEmailProviders do
  alias Core.Auth.PersonalEmailProviders.PersonalEmailProvider
  import Ecto.Query

  @spec exists_by_domain?(String.t()) :: boolean()
  def exists_by_domain?(domain) when is_binary(domain) do
    Core.Repo.exists?(from p in PersonalEmailProvider, where: p.domain == ^domain)
  end

  @spec exists?(String.t()) :: boolean()
  def exists?(domain), do: exists_by_domain?(domain)
end
