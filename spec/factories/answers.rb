FactoryBot.define do
  factory :answer do
    correction_text  { "Car = 56,73 l / Van = 38,68 kWh" }
    explanation_text { "On utilise la formule Consommation × Distance / 100" }
    key_concepts     { [ "énergie primaire", "rendement" ] }
    data_hints       { [ { "source" => "DT", "location" => "tableau Consommation" } ] }
    association :question
  end
end
