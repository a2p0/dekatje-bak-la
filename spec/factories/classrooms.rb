FactoryBot.define do
  factory :classroom do
    name        { "Terminale SIN" }
    school_year { "2026" }
    specialty   { "SIN" }
    access_code { "terminale-sin-#{SecureRandom.hex(3)}" }
    association :owner, factory: :user
  end
end
