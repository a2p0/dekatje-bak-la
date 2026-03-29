module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_student, :current_user

    def connect
      self.current_student = find_student
      self.current_user = find_user
      reject_unauthorized_connection unless current_student || current_user
    end

    private

    def find_student
      Student.find_by(id: request.session[:student_id])
    end

    def find_user
      env["warden"]&.user
    end
  end
end
