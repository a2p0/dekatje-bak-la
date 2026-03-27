FactoryBot.define do
  factory :extraction_job do
    status        { :pending }
    provider_used { :server }
    association :subject
  end
end
