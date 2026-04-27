require "rails_helper"

RSpec.describe "Filtrage des sujets par spécialité de classe", type: :feature do
  let(:teacher) { create(:user) }
  let(:exam_session) { create(:exam_session, owner: teacher) }

  let(:classroom_ac) { create(:classroom, :ac, owner: teacher) }
  let(:classroom_ee) { create(:classroom, :ee, owner: teacher) }

  let(:student_ac) { create(:student, classroom: classroom_ac, password: "password123") }
  let(:student_ee) { create(:student, classroom: classroom_ee, password: "password123") }

  let(:subject_ac) do
    create(:subject, :ac, :new_format, status: :published, owner: teacher, exam_session: exam_session).tap do |s|
      create(:part, :common_shared, exam_session: exam_session, title: "Partie commune AC")
      create(:part, section_type: :specific, specialty: :AC, subject: s, title: "Partie spécifique AC")
    end
  end

  let(:subject_tc) do
    create(:subject, :tronc_commun, :new_format, status: :published, owner: teacher, exam_session: exam_session)
  end

  before do
    create(:classroom_subject, classroom: classroom_ac, subject: subject_ac)
    create(:classroom_subject, classroom: classroom_ee, subject: subject_ac)
    create(:classroom_subject, classroom: classroom_ac, subject: subject_tc)
    create(:classroom_subject, classroom: classroom_ee, subject: subject_tc)
  end

  # ─────────────────────────────────────────────
  # US1 — Liste des sujets filtrée par spécialité
  # ─────────────────────────────────────────────

  describe "US1: Liste des sujets" do
    context "élève AC" do
      before { login_as_student(student_ac, classroom_ac) }

      it "affiche le sujet AC sans mention 'partie commune uniquement'" do
        visit student_root_path(access_code: classroom_ac.access_code)
        within("[data-subject-id='#{subject_ac.id}']") do
          expect(page).not_to have_text("partie commune uniquement")
        end
      end

      it "affiche le sujet tronc_commun avec mention 'partie commune uniquement'" do
        visit student_root_path(access_code: classroom_ac.access_code)
        within("[data-subject-id='#{subject_tc.id}']") do
          expect(page).to have_text("partie commune uniquement")
        end
      end
    end

    context "élève EE" do
      before { login_as_student(student_ee, classroom_ee) }

      it "affiche le sujet AC avec mention 'partie commune uniquement'" do
        visit student_root_path(access_code: classroom_ee.access_code)
        within("[data-subject-id='#{subject_ac.id}']") do
          expect(page).to have_text("partie commune uniquement")
        end
      end

      it "affiche le sujet tronc_commun avec mention 'partie commune uniquement'" do
        visit student_root_path(access_code: classroom_ee.access_code)
        within("[data-subject-id='#{subject_tc.id}']") do
          expect(page).to have_text("partie commune uniquement")
        end
      end

      it "n'affiche pas de mention pour un sujet EE (edge case: sujet de même spé)" do
        subject_ee = create(:subject, :ee, :new_format, status: :published, owner: teacher, exam_session: exam_session)
        create(:classroom_subject, classroom: classroom_ee, subject: subject_ee)
        visit student_root_path(access_code: classroom_ee.access_code)
        within("[data-subject-id='#{subject_ee.id}']") do
          expect(page).not_to have_text("partie commune uniquement")
        end
      end
    end
  end

  # ─────────────────────────────────────────────
  # US2 — Blocage accès partie spécifique
  # ─────────────────────────────────────────────

  describe "US2: Blocage accès partie spécifique" do
    let(:common_part)   { exam_session.common_parts.first }
    let(:specific_part) { subject_ac.parts.specific.first }
    let(:common_question) do
      create(:question, part: common_part, status: :validated)
    end
    let(:specific_question) do
      create(:question, part: specific_part, status: :validated)
    end

    before do
      subject_ac
      common_question
      specific_question
    end

    context "élève EE sur sujet AC" do
      before { login_as_student(student_ee, classroom_ee) }

      it "peut accéder à une question de la partie commune" do
        visit student_question_path(
          access_code: classroom_ee.access_code,
          subject_id: subject_ac.id,
          id: common_question.id
        )
        expect(page).not_to have_text("introuvable")
        expect(page).not_to have_text("non autorisé")
      end

      it "est redirigé si il tente d'accéder à une question de la partie spécifique AC via URL directe" do
        visit student_question_path(
          access_code: classroom_ee.access_code,
          subject_id: subject_ac.id,
          id: specific_question.id
        )
        expect(page).to have_current_path(student_root_path(access_code: classroom_ee.access_code))
        expect(page).to have_text("introuvable").or have_text("non autorisé").or have_text("partie spécifique")
      end
    end

    context "élève AC sur sujet AC" do
      before { login_as_student(student_ac, classroom_ac) }

      it "peut accéder à une question de la partie spécifique AC" do
        visit student_question_path(
          access_code: classroom_ac.access_code,
          subject_id: subject_ac.id,
          id: specific_question.id
        )
        expect(page).not_to have_text("introuvable")
      end
    end
  end
end
