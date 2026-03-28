FactoryBot.define do
  factory :part do
    number         { 1 }
    title          { "Partie #{Faker::Number.number(digits: 1)}" }
    objective_text { "Comparer les modes de transport" }
    section_type   { :common }
    position       { 1 }
    association    :subject
  end
end
