defmodule Core.WebTracker.Schemas.WebTrackerParams do
  @moduledoc """
  Struct and type definitions for web tracker event parameters.
  This module defines the expected shape of incoming web tracker events.
  """

  @enforce_keys [
    :tenant,
    :visitor_id,
    :origin,
    :ip,
    :event_type,
    :href,
    :hostname,
    :pathname,
    :user_agent,
    :language,
    :cookies_enabled
  ]

  defstruct [
    :tenant,
    :visitor_id,
    :origin,
    :ip,
    :event_type,
    :event_data,
    :href,
    :search,
    :hostname,
    :pathname,
    :referrer,
    :user_agent,
    :language,
    :cookies_enabled,
    :screen_resolution,
    :timestamp
  ]

  @type t :: %__MODULE__{
          tenant: String.t(),
          visitor_id: String.t(),
          origin: String.t(),
          ip: String.t(),
          event_type: String.t(),
          event_data: String.t() | nil,
          href: String.t(),
          search: String.t() | nil,
          hostname: String.t(),
          pathname: String.t(),
          referrer: String.t() | nil,
          user_agent: String.t(),
          language: String.t(),
          cookies_enabled: boolean(),
          screen_resolution: String.t() | nil,
          timestamp: DateTime.t() | nil
        }

  @doc """
  Creates a new WebTrackerParams struct from a map of parameters.
  Returns {:ok, params} if successful, {:error, reason} if validation fails.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(params) do
    # Convert camelCase keys to snake_case atoms and ensure all required fields
    params =
      params
      |> convert_keys()
      |> convert_timestamp()

    case validate_required_fields(params) do
      :ok ->
        struct = struct!(__MODULE__, params)
        {:ok, struct}

      {:error, _} = error ->
        error
    end
  end

  # Convert camelCase string keys to snake_case atoms
  defp convert_keys(params) do
    for {key, val} <- params,
        into: %{},
        do: {convert_key(key), val}
  end

  defp convert_key(key) when is_atom(key), do: key

  defp convert_key(key) when is_binary(key) do
    key
    |> Macro.underscore()
    |> String.to_existing_atom()
  rescue
    ArgumentError -> key
  end

  # Convert timestamp from milliseconds to DateTime
  defp convert_timestamp(%{timestamp: timestamp} = params)
       when is_number(timestamp) do
    # Convert milliseconds to seconds and create DateTime
    datetime = DateTime.from_unix!(div(timestamp, 1000), :second)
    %{params | timestamp: datetime}
  end

  defp convert_timestamp(params), do: params

  # Validate all required fields are present and of correct type
  defp validate_required_fields(params) do
    case Enum.find(@enforce_keys, fn key ->
           not Map.has_key?(params, key) or is_nil(params[key])
         end) do
      nil -> :ok
      missing_key -> {:error, "Missing required field: #{missing_key}"}
    end
  end
end
