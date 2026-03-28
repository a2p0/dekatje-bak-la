FactoryBot.define do
  factory :student_session do
    association :student
    association :subject
    mode { :autonomous }
    progression { {} }
    started_at { Time.current }
    last_activity_at { Time.current }
  end
end
