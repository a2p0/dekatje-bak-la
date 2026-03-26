class GenerateStudentCredentials
  # Alphanumeric sans caractères ambigus (0/O, 1/l/I)
  CHARSET = ("a".."z").to_a - [ "l", "o" ] + ("2".."9").to_a

  def self.call(first_name:, last_name:, classroom:)
    base = "#{first_name}.#{last_name}".parameterize(separator: ".")
    username = unique_username(base, classroom)
    password = Array.new(8) { CHARSET.sample }.join

    { username: username, password: password }
  end

  def self.unique_username(base, classroom)
    candidate = base
    counter = 2

    while classroom.students.exists?(username: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    candidate
  end
  private_class_method :unique_username
end
