# spec/factories/conversations.rb
FactoryBot.define do
  factory :conversation do
    association :student
    association :question
    messages { [] }
    provider_used { "anthropic" }
    tokens_used { 0 }
    streaming { false }
  end
end
