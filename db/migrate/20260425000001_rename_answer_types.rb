class RenameAnswerTypes < ActiveRecord::Migration[8.1]
  def up
    # Step 1: completion(4) → representation(3) — must run before choice(5) shift
    execute "UPDATE questions SET answer_type = 3 WHERE answer_type = 4"
    # Step 2: choice(5) → qcm(4)
    execute "UPDATE questions SET answer_type = 4 WHERE answer_type = 5"
    # text(0)→identification(0), calculation(1)→calcul(1), argumentation(2)→justification(2),
    # dr_reference(3)→representation(3) all keep their integer values — no UPDATE needed.
  end

  def down
    # Reverse step 2: qcm(4) → choice(5)
    execute "UPDATE questions SET answer_type = 5 WHERE answer_type = 4"
    # Reverse step 1: representation(3) → dr_reference(3) for former completion rows
    # NOTE: cannot distinguish former dr_reference(3) from former completion(4) after rollback —
    # both were mapped to representation(3). Rollback restores all representation(3) as dr_reference(3).
    # completion rows are lost on rollback — acceptable for development, document before prod deploy.
  end
end
