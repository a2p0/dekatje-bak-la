# frozen_string_literal: true

# Test seed — minimal data for tutor simulation CI.
# Creates a teacher, exam session, published subject with questions/answers.

teacher = User.find_or_initialize_by(email: "prof@test.com")
teacher.assign_attributes(
  first_name: "Jean",
  last_name: "Dupont",
  password: "password123",
  confirmed_at: Time.current
)
teacher.save!

# Load extraction data
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
  subject.assign_attributes(code: metadata["code"], status: :draft)
  # Attach placeholder PDFs (real files not needed for simulation)
  subject.subject_pdf.attach(
    io: StringIO.new("%PDF-1.4 test subject"),
    filename: "subject.pdf",
    content_type: "application/pdf"
  )
  subject.correction_pdf.attach(
    io: StringIO.new("%PDF-1.4 test correction"),
    filename: "correction.pdf",
    content_type: "application/pdf"
  )
  subject.save!
end

# Persist extraction data
unless exam_session.common_parts.any?
  PersistExtractedData.call(subject: subject, data: data)

  Question.where(part: subject.all_parts).update_all(status: Question.statuses[:validated])
  subject.update_column(:status, Subject.statuses[:published])
end

# Populate structured_correction for specific part A (043 POC).
# Files are kept in db/seeds/development/043_structured_correction/ and
# applied in the test seed so CI simulations can exercise the enriched prompt.
structured_dir = Rails.root.join("db", "seeds", "development", "043_structured_correction")
part_a = subject.parts.specific.find_by(number: "A")
if part_a
  part_a.questions.each do |q|
    json_path = structured_dir.join("#{q.number}.json")
    next unless File.exist?(json_path)
    next if q.answer&.structured_correction.present?

    q.answer&.update_column(:structured_correction, JSON.parse(File.read(json_path)))
  end
  populated = part_a.questions.joins(:answer).where.not(answers: { structured_correction: nil }).count
  puts "  043 POC: #{populated} questions with structured_correction populated"
end

# Create classroom + link
classroom = Classroom.find_or_initialize_by(access_code: "test-sim")
classroom.assign_attributes(name: "Test Simulation", school_year: "2025", specialty: "SIN", owner: teacher)
classroom.save!
ClassroomSubject.find_or_create_by!(classroom: classroom, subject: subject)

puts "  Test seed: Subject ##{subject.id} (#{Question.where(part: subject.all_parts).count} questions)"
