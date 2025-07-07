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
    :company_name
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
          company_name: String.t() | nil
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
        :company_name
      ])
      |> Jason.Encode.map(opts)
    end
  end
end
