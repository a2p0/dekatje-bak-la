class AuthenticateStudent
  def self.call(access_code:, username:, password:)
    classroom = Classroom.find_by(access_code: access_code)
    return nil unless classroom

    student = classroom.students.find_by(username: username)
    return nil unless student

    student.authenticate(password) || nil
  end
end
