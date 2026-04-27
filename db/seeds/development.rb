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
  year: metadata["year"].to_s,
  owner: teacher
) do |es|
  es.exam = metadata["exam"]
  es.region = metadata["region"] || :metropole
  es.variante = metadata["variante"] || :normale
end

subject = Subject.find_or_initialize_by(
  owner: teacher,
  exam_session: exam_session,
  specialty: metadata["specialty"]
)

if subject.new_record?
  subject.assign_attributes(
    code: metadata["code"],
    status: :draft
  )
  subject.save!(validate: false)
  puts "  Sujet créé: #{subject.title} (#{subject.specialty})"
end

# Attach PDFs if not already attached
seeds_dir = Rails.root.join("db", "seeds", "development")

unless subject.subject_pdf.attached?
  subject.subject_pdf.attach(
    io: File.open(seeds_dir.join("sujet_cime_2024.pdf")),
    filename: "sujet_cime_2024.pdf",
    content_type: "application/pdf"
  )
  puts "  PDF sujet attaché"
end

unless subject.correction_pdf.attached?
  subject.correction_pdf.attach(
    io: File.open(seeds_dir.join("corrige_cime_2024.pdf")),
    filename: "corrige_cime_2024.pdf",
    content_type: "application/pdf"
  )
  puts "  PDF corrigé attaché"
end

# Persist extraction data
unless exam_session.common_parts.any?
  PersistExtractedData.call(subject: subject, data: data)

  Question.where(part: subject.all_parts).update_all(status: Question.statuses[:validated])
  subject.update_column(:status, Subject.statuses[:published])

  puts "  Extraction persistée: #{Question.where(part: subject.all_parts).count} questions (publiées)"
end

# Create ExtractionJob record
ExtractionJob.find_or_create_by!(subject: subject) do |job|
  job.status = :done
  job.raw_json = raw
  job.provider_used = :server
end

# === C. Lien Classroom ↔ Subject ===

ClassroomSubject.find_or_create_by!(classroom: classroom, subject: subject)
puts "  Sujet lié à la classe: #{classroom.name}"

# === D. Classes AC + EE pour tests filtrage spécialité ===

classroom_ac = Classroom.find_or_initialize_by(access_code: "terminale-ac-2025")
classroom_ac.assign_attributes(
  name: "Terminale STI2D AC 2025",
  school_year: "2025",
  specialty: "AC",
  owner: teacher
)
classroom_ac.save!
puts "  Classe: #{classroom_ac.name} (#{classroom_ac.access_code})"

classroom_ee = Classroom.find_or_initialize_by(access_code: "terminale-ee-2025")
classroom_ee.assign_attributes(
  name: "Terminale STI2D EE 2025",
  school_year: "2025",
  specialty: "EE",
  owner: teacher
)
classroom_ee.save!
puts "  Classe: #{classroom_ee.name} (#{classroom_ee.access_code})"

ac_students_data = [
  { first_name: "Anya",   last_name: "AC",    username: "anya.ac",    specialty: :AC },
  { first_name: "Tuteur", last_name: "AC",    username: "tuteur.ac",  specialty: :AC,
    api_key: "sk-or-test-ac", api_provider: :openrouter }
]

ee_students_data = [
  { first_name: "Anya",   last_name: "EE",    username: "anya.ee",    specialty: :EE },
  { first_name: "Tuteur", last_name: "EE",    username: "tuteur.ee",  specialty: :EE,
    api_key: "sk-or-test-ee", api_provider: :openrouter }
]

[ [ ac_students_data, classroom_ac ], [ ee_students_data, classroom_ee ] ].each do |students, cls|
  students.each do |attrs|
    s = Student.find_or_initialize_by(username: attrs[:username], classroom: cls)
    s.assign_attributes(
      first_name: attrs[:first_name],
      last_name: attrs[:last_name],
      password: "eleve123",
      specialty: attrs[:specialty],
      api_key: attrs[:api_key],
      api_provider: attrs[:api_provider] || :openrouter
    )
    s.save!
    extra = attrs[:api_key] ? " (clé OpenRouter test)" : ""
    puts "  Élève: #{s.username} / eleve123#{extra}"
  end
end

# Assigner le sujet AC existant aux deux classes
ClassroomSubject.find_or_create_by!(classroom: classroom_ac, subject: subject)
ClassroomSubject.find_or_create_by!(classroom: classroom_ee, subject: subject)
puts "  Sujet #{subject.specialty&.upcase} lié aux classes AC et EE"

# === E. Sujet EE minimal pour tests cross-spé ===

subject_ee = Subject.find_or_initialize_by(
  owner: teacher,
  exam_session: exam_session,
  specialty: :EE
)

unless subject_ee.persisted?
  subject_ee.assign_attributes(
    code: "EE-TEST-001",
    status: :published
  )
  subject_ee.save!(validate: false)
  puts "  Sujet EE créé (#{subject_ee.specialty})"

  # Parts communs partagés avec exam_session existant (déjà créés par sujet AC)
  # Partie spécifique EE
  part_ee = Part.create!(
    section_type: :specific,
    specialty: :EE,
    number: 1,
    title: "Partie spécifique EE",
    objective_text: "Analyser un système de conversion d'énergie électrique",
    position: 1,
    subject: subject_ee
  )

  q1 = Question.create!(
    part: part_ee,
    number: "1.1",
    label: "Identifier les composants du convertisseur.",
    points: 2,
    answer_type: :identification,
    position: 1,
    status: :validated
  )
  Answer.create!(
    question: q1,
    correction_text: "Le convertisseur comprend un redresseur, un onduleur et un filtre LC.",
    key_concepts: [ "redresseur", "onduleur" ]
  )
  puts "  Sujet EE: #{Question.where(part: part_ee).count} questions"
end

ClassroomSubject.find_or_create_by!(classroom: classroom_ac, subject: subject_ee)
ClassroomSubject.find_or_create_by!(classroom: classroom_ee, subject: subject_ee)
puts "  Sujet EE lié aux classes AC et EE"

# === F. Résumé ===

puts ""
puts "--- Résumé ---"
puts "  Users: #{User.count} | Students: #{Student.count}"
puts "  ExamSessions: #{ExamSession.count} | Subjects: #{Subject.count}"
puts "  Parts: #{Part.count} | Questions: #{Question.count} | Answers: #{Answer.count}"
puts ""
puts "Enseignant : http://localhost:3000/users/sign_in"
puts "  → prof@test.com / password123"
puts ""
puts "Élèves SIN : http://localhost:3000/#{classroom.access_code}"
students_data.each do |attrs|
  extra = attrs[:api_key] ? " (clé API test)" : ""
  puts "  → #{attrs[:username]} / eleve123#{extra}"
end
puts ""
puts "Élèves AC : http://localhost:3000/#{classroom_ac.access_code}"
ac_students_data.each do |attrs|
  extra = attrs[:api_key] ? " (clé OpenRouter test)" : ""
  puts "  → #{attrs[:username]} / eleve123#{extra}"
end
puts ""
puts "Élèves EE : http://localhost:3000/#{classroom_ee.access_code}"
ee_students_data.each do |attrs|
  extra = attrs[:api_key] ? " (clé OpenRouter test)" : ""
  puts "  → #{attrs[:username]} / eleve123#{extra}"
end
puts ""
puts "Filtrage spé : élève AC → sujet AC complet, sujet EE = partie commune uniquement"
puts "Filtrage spé : élève EE → sujet AC = partie commune uniquement, sujet EE complet"
