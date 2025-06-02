defmodule Core.Auth.PersonalEmailProviders do
  @moduledoc """
  Context module for managing personal email provider domains.

  Provides functions for checking if a given domain is a known personal
  email provider. This is used to validate and categorize email addresses
  in the authentication system.
  """

  require OpenTelemetry.Tracer
  alias Core.Auth.PersonalEmailProviders.PersonalEmailProvider
  import Ecto.Query

  @spec exists_by_domain?(String.t()) :: boolean()
  def exists_by_domain?(domain) when is_binary(domain) do
    OpenTelemetry.Tracer.with_span "personal_email_providers.exists_by_domain" do
      OpenTelemetry.Tracer.set_attributes([
        {"domain", domain}
      ])

      result =
        Core.Repo.exists?(
          from p in PersonalEmailProvider, where: p.domain == ^domain
        )

      OpenTelemetry.Tracer.set_attributes([
        {"result.exists", result}
      ])

      result
    end
  end

  @spec exists?(String.t()) :: boolean()
  def exists?(domain), do: exists_by_domain?(domain)
end
