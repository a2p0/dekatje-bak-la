FactoryBot.define do
  factory :exam_session do
    title { "Polynésie 2024 CIME" }
    year { "2024" }
    region { :polynesie }
    exam { :bac }
    association :owner, factory: :user
  end
end
