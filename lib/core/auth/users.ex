defmodule Core.Auth.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  require Logger
  require OpenTelemetry.Tracer
  alias Core.Repo
  alias Core.Notifications.Slack
  alias Core.Utils.Tracing

  alias Core.Auth.Users.{User, UserToken, UserNotifier}
  alias Core.Auth.Tenants
  alias Core.Crm.Companies
  alias Core.Crm.Leads
  alias Application

  @hash_algorithm :sha256

  ## Database getters

  def get_user_by_email_token(token, context) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, context),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    OpenTelemetry.Tracer.with_span "users.register_user" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.user.email", Map.get(attrs, :email)}
      ])

      %User{}
      |> User.registration_changeset(attrs)
      |> User.extract_tenant_name_from_email()
      |> User.extract_domain_from_email()
      |> maybe_create_customeros_lead()
      |> create_tenant_if_not_exists()
      |> Repo.insert()
      |> deliver_new_user_slack_notification()
    end
  end

  defp create_tenant_if_not_exists(changeset) do
    case changeset do
      %{errors: []} ->
        domain = get_change(changeset, :domain)
        tenant_name = get_change(changeset, :tenant_name)

        case Tenants.get_or_create_tenant(tenant_name, domain) do
          {:ok, tenant} ->
            put_change(changeset, :tenant_id, tenant.id)

          {:error, reason} ->
            Tracing.error("Failed to register user: #{inspect(reason)}")

            add_error(
              changeset,
              :email,
              "Failed to create tenant: #{inspect(reason)}"
            )
        end

      _ ->
        changeset
    end
  end

  defp maybe_create_customeros_lead(changeset) do
    case changeset do
      %{errors: []} ->
        domain = get_change(changeset, :domain)
        email = get_change(changeset, :email)

        customeros_tenant_name =
          Application.get_env(:core, :customeros)[:customeros_tenant_name]

        {:ok, customeros_tenant} =
          Tenants.get_tenant_by_name(customeros_tenant_name)

        if customeros_tenant.primary_domain == domain do
          changeset
        else
          handle_lead_creation(changeset, domain, email, customeros_tenant_name)
        end

      _ ->
        changeset
    end
  end

  defp handle_lead_creation(changeset, domain, email, customeros_tenant_name) do
    case Companies.get_or_create_by_domain(domain) do
      {:ok, company} ->
        create_lead_for_company(
          changeset,
          company,
          email,
          customeros_tenant_name
        )

      {:error, reason} ->
        add_error(
          changeset,
          :lead,
          "Failed to create company: #{inspect(reason)}"
        )
    end
  end

  defp create_lead_for_company(
         changeset,
         company,
         email,
         customeros_tenant_name
       ) do
    lead_attrs = %{ref_id: company.id, type: :company}

    callback_after_lead_evaluation = fn fit ->
      login_or_register_user(email)

      Web.Endpoint.broadcast("events:#{email}", "event", %{
        type: :icp_fit_evaluation_complete,
        payload: %{
          is_fit: fit not in [:not_a_fit, :unknown]
        }
      })
    end

    case Leads.get_or_create(
           customeros_tenant_name,
           lead_attrs,
           callback_after_lead_evaluation,
           max_pages: 10
         ) do
      {:ok, lead} ->
        handle_lead_icp_fit(changeset, lead, email)

      {:error, reason} ->
        Tracing.error(
          "Failed to create lead for company #{company.id}: #{inspect(reason)}"
        )

        add_error(
          changeset,
          :lead,
          "Failed to create lead: #{inspect(reason)}"
        )
    end
  end

  defp handle_lead_icp_fit(changeset, lead, email) do
    case lead.icp_fit do
      :not_a_fit ->
        deliver_blocked_user_slack_notification(email)
        add_error(changeset, :lead, "Not a fit")

      :unknown ->
        deliver_blocked_user_slack_notification(email)
        add_error(changeset, :lead, "Unknown ICP fit")

      :moderate ->
        changeset

      :strong ->
        changeset

      nil ->
        add_error(changeset, :lead, "Lead still evaluating")
    end
  end

  defp deliver_new_user_slack_notification({:ok, user}) do
    email = user.email
    tenant_name = user.tenant_name

    Task.start(fn ->
      case Slack.notify_new_user(email, tenant_name) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error(
            "Failed to send Slack notification for user #{email} creation: #{inspect(reason)}"
          )

          reason
      end
    end)

    {:ok, user}
  end

  defp deliver_new_user_slack_notification(error) do
    error
  end

  defp deliver_blocked_user_slack_notification(email) do
    Task.start(fn ->
      case Slack.notify_blocked_user(email) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error(
            "Failed to send Slack notification for blocked user #{email}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    end)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, attrs) do
    user
    |> User.email_changeset(attrs)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <-
           UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(
      :tokens,
      UserToken.by_user_and_contexts_query(user, [context])
    )
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(
        %User{} = user,
        current_email,
        update_email_url_fun
      )
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} =
      UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)

    UserNotifier.deliver_update_email_instructions(
      user,
      update_email_url_fun.(encoded_token)
    )
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Confirms a user. Does nothing if they're already confirmed.
  """
  # NOTE: You could add a last_seen_at timestamp update here.
  def confirm_user(%User{confirmed_at: confirmed_at} = user)
      when is_nil(confirmed_at) do
    user
    |> User.confirm_changeset()
    |> Repo.update()
  end

  def confirm_user(%User{confirmed_at: confirmed_at} = user)
      when not is_nil(confirmed_at) do
    {:ok, user}
  end

  ## Authentication

  def login_or_register_user(email) do
    case get_user_by_email(email) do
      # Found existing user.
      %User{} = user ->
        {email_token, token} = UserToken.build_email_token(user, "magic_link")
        Repo.insert!(token)

        UserNotifier.deliver_login_link(
          user,
          "#{Web.Endpoint.url()}/signin/token/#{email_token}"
        )

      # New user, create a new account.
      _ ->
        case register_user(%{email: email}) do
          {:ok, user} ->
            {email_token, token} =
              UserToken.build_email_token(user, "magic_link")

            Repo.insert!(token)

            UserNotifier.deliver_register_link(
              user,
              "#{Web.Endpoint.url()}/signup/token/#{email_token}"
            )

          {:error, errors} ->
            {:error, parse_changeset_errors(errors)}
        end
    end
  end

  defp parse_changeset_errors(%Ecto.Changeset{errors: errors}) do
    Enum.map(errors, fn {key, {message, _}} -> {key, message} end)
  end

  @doc """
  Updates a user's tenant ID.
  """
  def update_user_tenant_id(%User{} = user, new_tenant_id) do
    user
    |> Ecto.Changeset.change(%{tenant_id: new_tenant_id})
    |> Repo.update()
  end

  @doc """
  Gets all users for a tenant.
  """
  def get_users_by_tenant(tenant_id) when is_binary(tenant_id) do
    OpenTelemetry.Tracer.with_span "users.get_users_by_tenant" do
      OpenTelemetry.Tracer.set_attributes([
        {"tenant.id", tenant_id}
      ])

      User
      |> where([u], u.tenant_id == ^tenant_id)
      |> where([u], not is_nil(u.confirmed_at))
      |> Repo.all()
    end
  end

  @doc """
  Marks a token as used by setting the used_at timestamp.
  """
  def mark_token_as_used(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        from(t in UserToken,
          where: t.token == ^hashed_token and t.context == ^context
        )
        |> Repo.update_all(set: [used_at: DateTime.utc_now()])

      :error ->
        :error
    end
  end
end
