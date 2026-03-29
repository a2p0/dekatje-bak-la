# spec/factories/student_insights.rb
FactoryBot.define do
  factory :student_insight do
    association :student
    association :subject
    association :question
    insight_type { "mastered" }
    concept { "energie primaire" }
    text { "L'eleve comprend le concept d'energie primaire." }
  end
end
