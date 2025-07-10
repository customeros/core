defmodule Core.Crm.Attribution.AttributionView do
  @moduledoc """
  Struct representing a attribution view entry.
  """

  defstruct [
    :id,
    :channel,
    :platform,
    :referrer,
    :city,
    :country_code,
    :inserted_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          channel: String.t(),
          platform: String.t(),
          referrer: String.t(),
          city: String.t(),
          country_code: String.t(),
          inserted_at: DateTime.t()
        }

  defimpl Jason.Encoder, for: __MODULE__ do
    def encode(attribution_view, opts) do
      attribution_view
      |> Map.take([
        :id,
        :channel,
        :platform,
        :referrer,
        :city,
        :country_code,
        :inserted_at
      ])
      |> Map.put(
        :inserted_at,
        Timex.format!(
          attribution_view.inserted_at,
          "{0D} {Mshort} {YYYY}, {h24}:{m}"
        )
      )
      |> Jason.Encode.map(opts)
    end
  end
end
