defmodule Core.Research.Builder.Profile do
  @derive Jason.Encoder

  @type t :: %__MODULE__{
          icp: String.t(),
          qualifying_attributes: list(String.t())
        }

  defstruct [
    :icp,
    :qualifying_attributes
  ]
end
