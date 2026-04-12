class GenerateStudentCredentials
  # Alphanumeric sans caractères ambigus (0/O, 1/l/I)
  CHARSET = ("a".."z").to_a - [ "l", "o" ] + ("2".."9").to_a
  Result = Struct.new(:username, :password, keyword_init: true)

  def self.call(first_name:, last_name:, classroom:) = new(first_name:, last_name:, classroom:).call

  def initialize(first_name:, last_name:, classroom:)
    @first_name = first_name
    @last_name = last_name
    @classroom = classroom
  end

  def call
    base = "#{@first_name}.#{@last_name}".parameterize(separator: ".")
    username = unique_username(base)
    password = Array.new(8) { CHARSET.sample }.join

    Result.new(username: username, password: password)
  end

  private

  def unique_username(base)
    candidate = base
    counter = 2

    while @classroom.students.exists?(username: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    candidate
  end
end
