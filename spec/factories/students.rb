FactoryBot.define do
  factory :student do
    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    username   { "#{Faker::Name.first_name.downcase}.#{Faker::Name.last_name.downcase}" }
    password   { "password123" }
    api_provider { 0 }
    association :classroom
  end
end
