FactoryBot.define do
  factory :question do
    number      { "1.1" }
    label       { "Calculer la consommation en litres pour 186 km." }
    points      { 2.0 }
    answer_type { :calcul }
    position    { 1 }
    status      { :draft }
    association :part
  end
end
