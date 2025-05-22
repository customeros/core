defmodule Core.Ai.Webpage.ClassificationTest do
  use ExUnit.Case, async: true
  alias Core.Ai.Webpage.Classification

  describe "struct creation" do
    test "creates a valid classification struct with all fields" do
      classification = %Classification{
        primary_topic: "AI Technology",
        secondary_topics: ["Machine Learning", "Deep Learning"],
        solution_focus: ["Automation", "Efficiency"],
        content_type: :article,
        industry_vertical: "Technology",
        key_pain_points: ["Cost", "Complexity"],
        value_proposition: "Streamline operations with AI",
        referenced_customers: ["Company A", "Company B"]
      }

      assert classification.primary_topic == "AI Technology"
      assert classification.secondary_topics == ["Machine Learning", "Deep Learning"]
      assert classification.solution_focus == ["Automation", "Efficiency"]
      assert classification.content_type == :article
      assert classification.industry_vertical == "Technology"
      assert classification.key_pain_points == ["Cost", "Complexity"]
      assert classification.value_proposition == "Streamline operations with AI"
      assert classification.referenced_customers == ["Company A", "Company B"]
    end

    test "creates a valid classification struct with minimal fields" do
      classification = %Classification{
        primary_topic: "AI Technology",
        content_type: :article
      }

      assert classification.primary_topic == "AI Technology"
      assert classification.content_type == :article
      assert classification.secondary_topics == nil
      assert classification.solution_focus == nil
      assert classification.industry_vertical == nil
      assert classification.key_pain_points == nil
      assert classification.value_proposition == nil
      assert classification.referenced_customers == nil
    end
  end

  describe "content types" do
    test "supports all defined content types" do
      valid_types = [
        :article,
        :whitepaper,
        :webinar,
        :case_study,
        :product_page,
        :solution_page,
        :testimonial,
        :research_report,
        :technical_docs,
        :unknown
      ]

      for type <- valid_types do
        classification = %Classification{
          primary_topic: "Test",
          content_type: type
        }
        assert classification.content_type == type
      end
    end
  end

  describe "JSON encoding" do
    test "can be encoded to JSON" do
      classification = %Classification{
        primary_topic: "AI Technology",
        secondary_topics: ["ML"],
        content_type: :article
      }

      json = Jason.encode!(classification)
      assert is_binary(json)
      assert String.contains?(json, "AI Technology")
      assert String.contains?(json, "ML")
      assert String.contains?(json, "article")
    end
  end
end
