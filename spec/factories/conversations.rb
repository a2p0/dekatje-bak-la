FactoryBot.define do
  factory :conversation do
    association :student
    association :subject
    provider_used { "anthropic" }
    tokens_used { 0 }
    lifecycle_state { "disabled" }
    tutor_state     { TutorState.default }
  end
end
