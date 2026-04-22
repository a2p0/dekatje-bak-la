require "rails_helper"

RSpec.describe "Student::Subjects::PartCompletions", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student)   { create(:student, classroom: classroom) }
  let(:subject_obj) { create(:subject, status: :published) }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_obj)
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  def post_part_completion(part)
    post student_subject_part_completion_path(
      access_code: classroom.access_code,
      subject_id:  subject_obj.id,
      part_id:     part.id
    )
  end

  describe "POST /:access_code/subjects/:subject_id/parts/:part_id/part_completion" do
    context "when the completed part is not the last remaining part" do
      let(:common_part)   { create(:part, subject: subject_obj, section_type: :common,   position: 1, number: 1) }
      let(:specific_part) { create(:part, subject: subject_obj, section_type: :specific, position: 2, number: 2) }
      let!(:common_q1)    { create(:question, part: common_part,   position: 1) }
      let!(:specific_q1)  { create(:question, part: specific_part, position: 1) }

      before do
        # Create a session so mark_part_completed! has something to update
        create(:student_session, student: student, subject: subject_obj, mode: :autonomous)
      end

      it "marks the part as completed" do
        post_part_completion(common_part)

        session_record = StudentSession.find_by(student: student, subject: subject_obj)
        expect(session_record.part_completed?(common_part.id)).to be true
      end

      it "redirects to the first unanswered question in the opposite section" do
        post_part_completion(common_part)

        expect(response).to redirect_to(
          student_question_path(
            access_code: classroom.access_code,
            subject_id:  subject_obj.id,
            id:          specific_q1.id
          )
        )
      end
    end

    context "when completing the last remaining part (all_parts_completed?)" do
      let(:part) { create(:part, subject: subject_obj, section_type: :common, position: 1, number: 1) }
      let!(:question) { create(:question, part: part, position: 1) }

      before do
        create(:student_session, student: student, subject: subject_obj, mode: :autonomous)
      end

      it "marks the part as completed" do
        post_part_completion(part)

        session_record = StudentSession.find_by(student: student, subject: subject_obj)
        expect(session_record.part_completed?(part.id)).to be true
      end

      it "redirects to the subject page (subject#show handles unanswered/completion flow)" do
        post_part_completion(part)

        expect(response).to redirect_to(
          student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
        )
      end
    end

    context "when not authenticated as a student" do
      before do
        delete student_session_path(access_code: classroom.access_code)
      end

      let(:part) { create(:part, subject: subject_obj, position: 1, number: 1) }

      it "redirects to the student login page" do
        post_part_completion(part)

        expect(response).to redirect_to(
          student_login_path(access_code: classroom.access_code)
        )
      end
    end
  end
end