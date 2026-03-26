class ResetStudentPassword
  CHARSET = GenerateStudentCredentials::CHARSET

  def self.call(student:)
    password = Array.new(8) { CHARSET.sample }.join
    student.update!(password: password)
    { password: password }
  end
end
