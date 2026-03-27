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
  end
end
