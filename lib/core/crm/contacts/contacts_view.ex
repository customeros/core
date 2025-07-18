defmodule Core.Crm.Contacts.ContactsView do
  defstruct [
    :id,
    :full_name,
    :job_title,
    :location,
    :time_current_position,
    :work_email,
    :phone_number,
    :linkedin,
    :avatar_url,
    :company_name,
    :current_time
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          full_name: String.t() | nil,
          job_title: String.t() | nil,
          location: String.t() | nil,
          time_current_position: String.t() | nil,
          work_email: String.t() | nil,
          phone_number: String.t() | nil,
          linkedin: String.t() | nil,
          avatar_url: String.t() | nil,
          company_name: String.t() | nil,
          current_time: String.t() | nil
        }

  defimpl Jason.Encoder, for: __MODULE__ do
    def encode(contact_view, opts) do
      contact_view
      |> Map.take([
        :id,
        :full_name,
        :job_title,
        :location,
        :time_current_position,
        :work_email,
        :phone_number,
        :linkedin,
        :avatar_url,
        :company_name,
        :current_time
      ])
      |> Jason.Encode.map(opts)
    end
  end
end
