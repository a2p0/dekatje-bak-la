FactoryBot.define do
  factory :part do
    number         { 1 }
    title          { "Partie #{Faker::Number.number(digits: 1)}" }
    objective_text { "Comparer les modes de transport" }
    section_type   { :common }
    position       { 1 }
    subject        { association(:subject) }

    trait :common_shared do
      section_type   { :common }
      subject        { nil }
      exam_session   { association(:exam_session) }
    end

    trait :specific do
      section_type { :specific }
      specialty    { :ITEC }
    end
  end
end
