FactoryBot.define do
  factory :classroom_subject do
    association :classroom
    association :subject
  end
end
