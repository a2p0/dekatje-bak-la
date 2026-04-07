# frozen_string_literal: true

# Development seed — idempotent, safe to run multiple times.
# For a full reset: bin/rails db:seed:replant

# === A. Enseignant, Classe, Élèves ===

teacher = User.find_or_initialize_by(email: "prof@test.com")
teacher.assign_attributes(
  first_name: "Jean",
  last_name: "Dupont",
  password: "password123",
  confirmed_at: Time.current
)
teacher.save!
puts "  Enseignant: prof@test.com / password123"

classroom = Classroom.find_or_initialize_by(access_code: "terminale-sin-2025")
classroom.assign_attributes(
  name: "Terminale STI2D SIN 2025",
  school_year: "2025",
  specialty: "SIN",
  owner: teacher
)
classroom.save!
puts "  Classe: #{classroom.name} (#{classroom.access_code})"

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

# === B. ExamSession + Subject + données extraites ===

json_path = Rails.root.join("db", "seeds", "development", "claude_extraction.json")
raw = File.read(json_path)
json_str = raw.gsub(/\A```json\n?/, "").gsub(/\n?```\z/, "")
data = JSON.parse(json_str)

metadata = data["metadata"]

exam_session = ExamSession.find_or_create_by!(
  title: metadata["title"],
  year: metadata["year"].to_i,
  owner: teacher
) do |es|
  es.exam_type = metadata["exam_type"]
  es.region = :metropole
end

subject = Subject.find_or_initialize_by(
  title: metadata["title"],
  year: metadata["year"].to_i,
  owner: teacher,
  exam_session: exam_session
)

if subject.new_record?
  subject.assign_attributes(
    exam_type: metadata["exam_type"],
    specialty: metadata["specialty"],
    region: :metropole,
    status: :draft
  )
  subject.save!(validate: false)
  puts "  Sujet créé: #{subject.title} (#{subject.specialty})"
end

unless exam_session.common_parts.any?
  PersistExtractedData.call(subject: subject, data: data)

  Question.where(part: subject.all_parts).update_all(status: Question.statuses[:validated])
  subject.update_column(:status, Subject.statuses[:published])

  puts "  Extraction persistée: #{Question.where(part: subject.all_parts).count} questions (publiées)"
end

# === C. Lien Classroom ↔ Subject ===

ClassroomSubject.find_or_create_by!(classroom: classroom, subject: subject)
puts "  Sujet lié à la classe: #{classroom.name}"

# === D. Résumé ===

puts ""
puts "--- Résumé ---"
puts "  Users: #{User.count} | Students: #{Student.count}"
puts "  ExamSessions: #{ExamSession.count} | Subjects: #{Subject.count}"
puts "  Parts: #{Part.count} | Questions: #{Question.count} | Answers: #{Answer.count}"
puts ""
puts "Enseignant : http://localhost:3000/users/sign_in"
puts "  → prof@test.com / password123"
puts ""
puts "Élèves : http://localhost:3000/#{classroom.access_code}"
students_data.each do |attrs|
  extra = attrs[:api_key] ? " (clé API test)" : ""
  puts "  → #{attrs[:username]} / eleve123#{extra}"
end
