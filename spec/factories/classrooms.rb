FactoryBot.define do
  factory :classroom do
    name        { "Terminale SIN" }
    school_year { "2026" }
    specialty   { "SIN" }
    access_code { "terminale-sin-#{SecureRandom.hex(3)}" }
    association :owner, factory: :user

    trait :sin  do specialty { "SIN"  }; name { "Terminale SIN" };  access_code { "terminale-sin-#{SecureRandom.hex(3)}" }; end
    trait :itec do specialty { "ITEC" }; name { "Terminale ITEC" }; access_code { "terminale-itec-#{SecureRandom.hex(3)}" }; end
    trait :ee   do specialty { "EE"   }; name { "Terminale EE" };   access_code { "terminale-ee-#{SecureRandom.hex(3)}" }; end
    trait :ac   do specialty { "AC"   }; name { "Terminale AC" };   access_code { "terminale-ac-#{SecureRandom.hex(3)}" }; end
  end
end
