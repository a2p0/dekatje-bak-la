class AuthenticateStudent
  def self.call(...) = new(...).call

  def initialize(access_code:, username:, password:)
    @access_code = access_code
    @username = username
    @password = password
  end

  def call
    classroom = Classroom.find_by(access_code: @access_code)
    return nil unless classroom

    student = classroom.students.find_by(username: @username)
    return nil unless student

    student.authenticate(@password) || nil
  end
end
