FactoryBot.define do
  factory :subject do
    title       { "Sujet BAC STI2D #{Faker::Number.number(digits: 4)}" }
    year        { "2026" }
    exam_type   { :bac }
    specialty   { :SIN }
    region      { :metropole }
    status      { :draft }
    association :owner, factory: :user

    after(:build) do |subject|
      subject.enonce_file.attach(
        io: StringIO.new("%PDF-1.4 fake enonce"),
        filename: "enonce.pdf",
        content_type: "application/pdf"
      )
      subject.dt_file.attach(
        io: StringIO.new("%PDF-1.4 fake dt"),
        filename: "dt.pdf",
        content_type: "application/pdf"
      )
      subject.dr_vierge_file.attach(
        io: StringIO.new("%PDF-1.4 fake dr vierge"),
        filename: "dr_vierge.pdf",
        content_type: "application/pdf"
      )
      subject.dr_corrige_file.attach(
        io: StringIO.new("%PDF-1.4 fake dr corrige"),
        filename: "dr_corrige.pdf",
        content_type: "application/pdf"
      )
      subject.questions_corrigees_file.attach(
        io: StringIO.new("%PDF-1.4 fake questions corrigees"),
        filename: "questions_corrigees.pdf",
        content_type: "application/pdf"
      )
    end

    trait :new_format do
      association :exam_session

      after(:build) do |subject|
        # Remove legacy files
        %i[enonce_file dt_file dr_vierge_file dr_corrige_file questions_corrigees_file].each do |file|
          subject.public_send(file).detach if subject.public_send(file).attached?
        end

        subject.subject_pdf.attach(
          io: StringIO.new("%PDF-1.4 fake subject pdf"),
          filename: "subject.pdf",
          content_type: "application/pdf"
        )
        subject.correction_pdf.attach(
          io: StringIO.new("%PDF-1.4 fake correction pdf"),
          filename: "correction.pdf",
          content_type: "application/pdf"
        )
      end
    end

    trait :no_files do
      after(:build) do |subject|
        %i[enonce_file dt_file dr_vierge_file dr_corrige_file questions_corrigees_file].each do |file|
          subject.public_send(file).detach if subject.public_send(file).attached?
        end
      end
    end
  end
end
