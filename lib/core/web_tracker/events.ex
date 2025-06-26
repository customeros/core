defmodule Core.WebTracker.Events do
  @moduledoc """
  Context module for managing web tracker events.
  Handles all business logic and database operations related to web tracker events.
  """
  import Ecto.Query
  import Ecto.Changeset
  require OpenTelemetry.Tracer

  alias Core.Repo
  alias Core.WebTracker.Events.Event
  alias Core.Utils.MapUtils
  alias Core.WebTracker.Sessions
  alias Core.WebTracker.CompanyEnrichmentJob
  alias Core.Utils.Tracing

  @doc """
  Creates a new web tracker event.
  """
  def create(attrs) do
    OpenTelemetry.Tracer.with_span "events.create" do
      OpenTelemetry.Tracer.set_attributes([
        {"event.visitor_id", Map.get(attrs, :visitor_id)},
        {"event.type", Map.get(attrs, :event_type)},
        {"event.tenant", Map.get(attrs, :tenant)},
        {"event.ip", Map.get(attrs, :ip)}
      ])

      result =
        %Event{}
        |> Event.changeset(attrs |> MapUtils.to_snake_case_map())
        |> maybe_put_session_id()
        |> Repo.insert()
        |> after_insert()

      case result do
        {:ok, event} ->
          OpenTelemetry.Tracer.set_attributes([
            {"event.id", event.id},
            {"event.session_id", event.session_id}
          ])

          Tracing.ok()
          result

        {:error, changeset} ->
          Tracing.error(
            "event_creation_failed",
            "Failed to create web tracker event",
            errors: format_changeset_errors(changeset)
          )

          result
      end
    end
  end

  def get_visited_pages(session_id) do
    pathnames =
      Event
      |> where([e], e.session_id == ^session_id and not is_nil(e.href))
      |> group_by([e], e.href)
      |> select([e], e.href)
      |> Repo.all()

    case pathnames do
      [] -> {:error, :not_found}
      results -> {:ok, results}
    end
  end

  defp maybe_put_session_id(changeset) do
    # Check if session_id is already set in the changeset data or changes
    session_id = get_field(changeset, :session_id)

    if is_nil(session_id) do
      OpenTelemetry.Tracer.with_span "events.maybe_put_session_id" do
        OpenTelemetry.Tracer.set_attributes([
          {"session.creation_type", "new_or_existing"}
        ])

        case Sessions.get_or_create_session(
               Map.merge(changeset.data, changeset.changes)
             ) do
          {:ok, session} ->
            OpenTelemetry.Tracer.set_attributes([
              {"session.id", session.id},
              {"session.created", session.just_created}
            ])

            changeset
            |> put_change(:session_id, session.id)
            |> put_change(:with_new_session, session.just_created)

          {:error, :ip_is_threat} ->
            Tracing.warning(
              :ip_is_threat,
              "IP is threat, skipping session creation"
            )

            add_error(changeset, :session_id, :ip_is_threat)

          {:error, reason} ->
            Tracing.error(reason, "Failed to create/get session")
            add_error(changeset, :session_id, reason)
        end
      end
    else
      OpenTelemetry.Tracer.with_span "events.maybe_put_session_id" do
        OpenTelemetry.Tracer.set_attributes([
          {"session.creation_type", "existing"},
          {"session.id", session_id}
        ])

        changeset
      end
    end
  end

  defp after_insert({:ok, %Event{} = event}) do
    OpenTelemetry.Tracer.with_span "events.after_insert" do
      OpenTelemetry.Tracer.set_attributes([
        {"event.id", event.id},
        {"event.session_id", event.session_id},
        {"event.type", event.event_type}
      ])

      Sessions.update_last_event(event.session_id, event.event_type)
      CompanyEnrichmentJob.enqueue(event)
      {:ok, event}
    end
  end

  defp after_insert(result), do: result

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
