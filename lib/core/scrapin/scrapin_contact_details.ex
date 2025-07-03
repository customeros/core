defmodule Core.ScrapinContactDetails do
  @moduledoc """
  Struct for the person details in ScrapIn contact response.
  Represents the detailed contact information from LinkedIn.
  """

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          public_identifier: String.t() | nil,
          linked_in_identifier: String.t() | nil,
          member_identifier: String.t() | nil,
          linkedin_url: String.t() | nil,
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          headline: String.t() | nil,
          location: String.t() | nil,
          summary: String.t() | nil,
          photo_url: String.t() | nil,
          background_url: String.t() | nil,
          open_to_work: boolean() | nil,
          premium: boolean() | nil,
          show_verification_badge: boolean() | nil,
          creation_date: map() | nil,
          follower_count: integer() | nil,
          positions: ScrapinContactPositions.t() | nil,
          schools: ScrapinContactSchools.t() | nil,
          skills: [String.t()] | nil,
          languages: [String.t()] | nil,
          languages_with_proficiency: [ScrapinContactLanguage.t()] | nil,
          recommendations: ScrapinContactRecommendations.t() | nil,
          certifications: ScrapinContactCertifications.t() | nil,
          test_scores: ScrapinContactTestScores.t() | nil,
          volunteering_experiences: ScrapinContactVolunteering.t() | nil,
          interests: ScrapinContactInterests.t() | nil
        }

  defstruct [
    :public_identifier,
    :linked_in_identifier,
    :member_identifier,
    :linkedin_url,
    :first_name,
    :last_name,
    :headline,
    :location,
    :summary,
    :photo_url,
    :background_url,
    :open_to_work,
    :premium,
    :show_verification_badge,
    :creation_date,
    :follower_count,
    :positions,
    :schools,
    :skills,
    :languages,
    :languages_with_proficiency,
    :recommendations,
    :certifications,
    :test_scores,
    :volunteering_experiences,
    :interests
  ]
end

defmodule Core.ScrapinContactPositions do
  @moduledoc """
  Struct for positions data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          positions_count: integer() | nil,
          position_history: [ScrapinContactPosition.t()] | nil
        }

  defstruct [
    :positions_count,
    :position_history
  ]
end

defmodule Core.ScrapinContactPosition do
  @moduledoc """
  Struct for individual position data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          title: String.t() | nil,
          company_name: String.t() | nil,
          company_location: String.t() | nil,
          description: String.t() | nil,
          start_end_date: map() | nil,
          company_logo: String.t() | nil,
          linked_in_url: String.t() | nil,
          linked_in_id: String.t() | nil,
          contract_type: String.t() | nil
        }

  defstruct [
    :title,
    :company_name,
    :company_location,
    :description,
    :start_end_date,
    :company_logo,
    :linked_in_url,
    :linked_in_id,
    :contract_type
  ]
end

defmodule Core.ScrapinContactSchools do
  @moduledoc """
  Struct for schools/education data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          educations_count: integer() | nil,
          education_history: [ScrapinContactEducation.t()] | nil
        }

  defstruct [
    :educations_count,
    :education_history
  ]
end

defmodule Core.ScrapinContactEducation do
  @moduledoc """
  Struct for individual education data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          school_name: String.t() | nil,
          degree_name: String.t() | nil,
          field_of_study: String.t() | nil,
          start_end_date: map() | nil,
          school_logo: String.t() | nil,
          linked_in_url: String.t() | nil
        }

  defstruct [
    :school_name,
    :degree_name,
    :field_of_study,
    :start_end_date,
    :school_logo,
    :linked_in_url
  ]
end

defmodule Core.ScrapinContactLanguage do
  @moduledoc """
  Struct for language proficiency data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          language: String.t() | nil,
          proficiency: String.t() | nil
        }

  defstruct [
    :language,
    :proficiency
  ]
end

defmodule Core.ScrapinContactRecommendations do
  @moduledoc """
  Struct for recommendations data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          recommendations_count: integer() | nil,
          recommendation_history: [ScrapinContactRecommendation.t()] | nil
        }

  defstruct [
    :recommendations_count,
    :recommendation_history
  ]
end

defmodule Core.ScrapinContactRecommendation do
  @moduledoc """
  Struct for individual recommendation data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          description: String.t() | nil,
          author_fullname: String.t() | nil,
          author_url: String.t() | nil,
          caption: String.t() | nil
        }

  defstruct [
    :description,
    :author_fullname,
    :author_url,
    :caption
  ]
end

defmodule Core.ScrapinContactCertifications do
  @moduledoc """
  Struct for certifications data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          certifications_count: integer() | nil,
          certification_history: [ScrapinContactCertification.t()] | nil
        }

  defstruct [
    :certifications_count,
    :certification_history
  ]
end

defmodule Core.ScrapinContactCertification do
  @moduledoc """
  Struct for individual certification data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          name: String.t() | nil,
          issued_date: String.t() | nil,
          organization_name: String.t() | nil,
          organization_url: String.t() | nil
        }

  defstruct [
    :name,
    :issued_date,
    :organization_name,
    :organization_url
  ]
end

defmodule Core.ScrapinContactTestScores do
  @moduledoc """
  Struct for test scores data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          test_scores_count: integer() | nil,
          test_score_history: [ScrapinContactTestScore.t()] | nil
        }

  defstruct [
    :test_scores_count,
    :test_score_history
  ]
end

defmodule Core.ScrapinContactTestScore do
  @moduledoc """
  Struct for individual test score data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          test_title: String.t() | nil,
          score: String.t() | nil
        }

  defstruct [
    :test_title,
    :score
  ]
end

defmodule Core.ScrapinContactVolunteering do
  @moduledoc """
  Struct for volunteering experiences data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          volunteering_experiences_count: integer() | nil,
          volunteering_experience_history: [map()] | nil
        }

  defstruct [
    :volunteering_experiences_count,
    :volunteering_experience_history
  ]
end

defmodule Core.ScrapinContactInterests do
  @moduledoc """
  Struct for interests data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          companies: [ScrapinContactInterestCompany.t()] | nil,
          top_voices: [ScrapinContactInterestPerson.t()] | nil
        }

  defstruct [
    :companies,
    :top_voices
  ]
end

defmodule Core.ScrapinContactInterestCompany do
  @moduledoc """
  Struct for company interest data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          name: String.t() | nil,
          url: String.t() | nil,
          linkedin_identifier: String.t() | nil,
          follower_count: integer() | nil,
          slug: String.t() | nil
        }

  defstruct [
    :name,
    :url,
    :linkedin_identifier,
    :follower_count,
    :slug
  ]
end

defmodule Core.ScrapinContactInterestPerson do
  @moduledoc """
  Struct for person interest data in ScrapIn contact response.
  """

  @type t :: %__MODULE__{
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          linkedin_identifier: String.t() | nil,
          public_identifier: String.t() | nil,
          followers_count: integer() | nil
        }

  defstruct [
    :first_name,
    :last_name,
    :linkedin_identifier,
    :public_identifier,
    :followers_count
  ]
end
