defmodule Core.Researcher.IcpBuilder.Profile do
  @moduledoc """
  Defines the data structure for Ideal Customer Profile (ICP) profiles.

  This module provides the core data structure used to represent ICP profiles,
  including the profile description and qualifying attributes that define
  an ideal customer profile.
  """

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
