# frozen_string_literal: true

# Idempotent seed — safe to run multiple times.
# Usage: bin/rails db:seed

puts "=== Seeding DekatjeBakLa ==="

# --- Enseignant ---
teacher = User.find_or_initialize_by(email: "prof@test.com")
teacher.assign_attributes(
  first_name: "Jean",
  last_name: "Dupont",
  password: "password123",
  confirmed_at: Time.current
)
teacher.save!
puts "  Enseignant: prof@test.com / password123"

# --- Classe ---
classroom = Classroom.find_or_initialize_by(access_code: "terminale-sin-2025")
classroom.assign_attributes(
  name: "Terminale STI2D SIN 2025",
  school_year: "2025",
  specialty: "SIN",
  owner: teacher
)
classroom.save!
puts "  Classe: #{classroom.name} (#{classroom.access_code})"

# --- Élèves ---
students_data = [
  { first_name: "Anya",   last_name: "Martineau", username: "anya.martineau",  specialty: :SIN },
  { first_name: "Lucas",  last_name: "Bélanger",  username: "lucas.belanger",  specialty: :ITEC },
  { first_name: "Maëlys", last_name: "Rivière",   username: "maelys.riviere",  specialty: :SIN,
    api_key: "sk-test", api_provider: :anthropic }
]

students_data.each do |attrs|
  student = Student.find_or_initialize_by(username: attrs[:username], classroom: classroom)
  student.assign_attributes(
    first_name: attrs[:first_name],
    last_name: attrs[:last_name],
    password: "eleve123",
    specialty: attrs[:specialty],
    api_key: attrs[:api_key],
    api_provider: attrs[:api_provider] || :openrouter
  )
  student.save!
  extra = attrs[:api_key] ? " (clé API test)" : ""
  puts "  Élève: #{student.username} / eleve123#{extra}"
end

puts ""
puts "=== Seed terminé ==="
puts ""
puts "Enseignant : http://localhost:3000/users/sign_in"
puts "  → prof@test.com / password123"
puts ""
puts "Élèves : http://localhost:3000/#{classroom.access_code}"
students_data.each do |attrs|
  extra = attrs[:api_key] ? " (clé API test)" : ""
  puts "  → #{attrs[:username]} / eleve123#{extra}"
end
