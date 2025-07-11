defmodule Core.WebTracker.Events.Event do
  @moduledoc """
  Schema definition for web tracker events.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.WebTracker.OriginTenantMapper
  alias Core.Utils.IdGenerator
  alias Core.Utils.Tracing

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  # Constants
  @id_prefix "wevnt"

  # Known event types
  @event_types [:page_view, :page_exit, :click, :identify]

  def event_types, do: @event_types

  schema "web_tracker_events" do
    # Required fields
    field(:tenant, :string)
    field(:tenant_id, :string)
    field(:session_id, :string)

    # Event information
    field(:ip, :string)
    field(:visitor_id, :string)
    field(:event_type, :string)
    field(:event_data, :string)
    field(:timestamp, :utc_datetime)
    field(:href, :string)
    field(:origin, :string)
    field(:search, :string)
    field(:hostname, :string)
    field(:pathname, :string)
    field(:referrer, :string)
    field(:user_agent, :string)
    field(:language, :string)
    field(:cookies_enabled, :boolean)
    field(:screen_resolution, :string)
    field(:with_new_session, :boolean, virtual: true)

    timestamps(type: :utc_datetime)
  end

  @type event_type :: :page_view | :page_exit | :click | :identify

  @type t :: %__MODULE__{
          id: String.t(),
          tenant: String.t(),
          tenant_id: String.t() | nil,
          session_id: String.t(),
          ip: String.t() | nil,
          visitor_id: String.t() | nil,
          event_type: String.t() | nil,
          event_data: String.t() | nil,
          timestamp: DateTime.t() | nil,
          href: String.t() | nil,
          origin: String.t() | nil,
          search: String.t() | nil,
          hostname: String.t() | nil,
          pathname: String.t() | nil,
          referrer: String.t() | nil,
          user_agent: String.t() | nil,
          language: String.t() | nil,
          cookies_enabled: boolean() | nil,
          screen_resolution: String.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          with_new_session: boolean() | nil
        }

  @doc """
  Returns the ID prefix used for web tracker events.
  """
  def id_prefix, do: @id_prefix

  @doc """
  Validates the changeset for a web tracker event.
  """
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :ip,
      :visitor_id,
      :event_type,
      :event_data,
      :href,
      :origin,
      :search,
      :hostname,
      :pathname,
      :referrer,
      :user_agent,
      :language,
      :cookies_enabled,
      :screen_resolution,
      :with_new_session,
      :tenant,
      :tenant_id
    ])
    |> put_id(attrs)
    |> put_tenant(attrs)
    |> put_timestamp(attrs)
    |> validate_required([
      :ip,
      :visitor_id,
      :event_type,
      :event_data,
      :href,
      :origin,
      :user_agent,
      :tenant,
      :tenant_id
    ])
    |> detect_bot()
    |> detect_suspicious_referrer()
  end

  def put_tenant(changeset, attrs) do
    case OriginTenantMapper.get_tenant_for_origin(attrs[:origin]) do
      {:ok, %Core.Auth.Tenants.Tenant{id: tenant_id, name: tenant_name}} ->
        changeset
        |> put_change(:tenant_id, tenant_id)
        |> put_change(:tenant, tenant_name)

      {:error, _} ->
        changeset
        |> put_change(:tenant, nil)
        |> add_error(:origin, "Invalid origin")
    end
  end

  def put_id(changeset, attrs) do
    if is_nil(attrs[:id]) do
      put_change(changeset, :id, IdGenerator.generate_id_21(id_prefix()))
    else
      changeset
    end
  end

  def put_timestamp(changeset, attrs) do
    if is_nil(attrs[:timestamp]) do
      put_change(changeset, :timestamp, DateTime.utc_now())
    else
      changeset
    end
  end

  def detect_bot(changeset) do
    user_agent = get_field(changeset, :user_agent)
    ip = get_field(changeset, :ip)
    origin = get_field(changeset, :origin)
    referrer = get_field(changeset, :referrer)

    # Use sophisticated bot detection
    case Core.WebTracker.BotDetector.detect_bot(
           user_agent || "",
           ip || "",
           origin || "",
           referrer || ""
         ) do
      {:ok, %{bot: true, confidence: confidence}} ->
        add_error(
          changeset,
          :user_agent,
          "Bot detected with confidence #{Float.round(confidence, 2)}"
        )

      {:ok, %{bot: false}} ->
        changeset

      {:error, reason} ->
        Tracing.error(reason, "Bot detection failed")
        # Fall back to simple detection if sophisticated detection fails
        if bot_user_agent?(user_agent) do
          add_error(changeset, :user_agent, "Bot requests are not allowed")
        else
          changeset
        end
    end
  end

  def detect_suspicious_referrer(changeset) do
    referrer = get_field(changeset, :referrer)

    case referrer do
      nil ->
        changeset

      "" ->
        changeset

      ref when is_binary(ref) ->
        if suspicious_referrer?(ref) do
          add_error(changeset, :referrer, "Suspicious referrer detected")
        else
          changeset
        end

      _ ->
        add_error(changeset, :referrer, "Invalid referrer format")
    end
  end

  ## Private Validation Helpers ##

  defp bot_user_agent?(user_agent) do
    String.match?(String.downcase(user_agent), ~r/(bot|crawler|spider)/)
  end

  defp suspicious_referrer?(referrer) do
    String.match?(String.downcase(referrer), ~r/(porn|xxx|gambling|casino)/)
  end
end
