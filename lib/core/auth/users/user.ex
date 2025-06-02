defmodule Core.Auth.Users.User do
  @moduledoc """
  Provides user account management functionality including registration, authentication,
  and profile management.

  This module handles:
  - User registration and account creation
  - Email validation and changes
  - Account confirmation and status tracking
  - Password hashing and security
  - User profile data management
  - Database schema and validation rules

  The module implements secure user management practices including email validation,
  proper password handling, and account state management.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Utils.DomainExtractor
  alias Core.Utils.PrimaryDomainFinder
  alias Core.Auth.PersonalEmailProviders

  @derive {Jason.Encoder,
           only: [
             :id,
             :email,
             :confirmed_at,
             :tenant_id,
             :inserted_at,
             :updated_at
           ]}
  @primary_key {:id, :string, autogenerate: false}
  schema "users" do
    field(:email, :string)
    field(:confirmed_at, :naive_datetime)
    field(:tenant_id, :string)
    field(:domain, :string, virtual: true)
    field(:tenant_name, :string, virtual: true)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          email: String.t(),
          confirmed_at: NaiveDateTime.t() | nil,
          tenant_id: String.t(),
          domain: String.t() | nil,
          tenant_name: String.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  A user changeset for registration.

  It is important to validate the length of email addresses.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour.

  ## Options

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :tenant_id])
    |> maybe_put_id()
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email], message: "Huston, we have a blank")
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
      message: "This seems like an invalid email address"
    )
    |> validate_length(:email, max: 160)
    |> validate_personal_email_domain()
    |> maybe_validate_unique_email(opts)
  end

  defp validate_personal_email_domain(changeset) do
    case get_change(changeset, :email) do
      nil ->
        changeset

      email ->
        case DomainExtractor.extract_domain_from_email(String.downcase(email)) do
          {:ok, domain} ->
            if PersonalEmailProviders.exists?(domain) do
              add_error(
                changeset,
                :email,
                "Please sign in with your work email"
              )
            else
              changeset
            end

          {:error, _} ->
            changeset
        end
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Core.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  defp maybe_put_id(%Ecto.Changeset{data: %{id: nil}} = changeset) do
    put_change(changeset, :id, Core.Utils.IdGenerator.generate_id_21("user"))
  end

  defp maybe_put_id(changeset), do: changeset

  def extract_tenant_name_from_email(changeset) do
    case changeset do
      %{errors: []} ->
        email = get_change(changeset, :email)

        with {:ok, domain} <- DomainExtractor.extract_domain_from_email(email),
             {:ok, primary_domain} <-
               PrimaryDomainFinder.get_primary_domain(domain) do
          tenant_name =
            primary_domain
            |> String.replace(".", "")

          put_change(changeset, :tenant_name, tenant_name)
        else
          {:error, _} -> add_error(changeset, :email, "invalid email domain")
        end

      _ ->
        changeset
    end
  end

  def extract_domain_from_email(changeset) do
    case changeset do
      %{errors: []} ->
        email = get_change(changeset, :email, "")

        case String.split(email, "@") do
          [_, domain] ->
            put_change(changeset, :domain, domain)

          _ ->
            add_error(changeset, :email, "invalid email domain")
        end

      _ ->
        changeset
    end
  end
end
