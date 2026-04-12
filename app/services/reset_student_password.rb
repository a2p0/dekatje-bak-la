class ResetStudentPassword
  CHARSET = GenerateStudentCredentials::CHARSET

  def self.call(student:) = new(student:).call

  def initialize(student:)
    @student = student
  end

  def call
    password = Array.new(8) { CHARSET.sample }.join
    @student.update!(password: password)
    password
  end
end
