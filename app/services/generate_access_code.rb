class GenerateAccessCode
  def self.call(specialty:, school_year:)
    base = [specialty, school_year].compact.join("-").parameterize
    candidate = base
    counter = 2

    while Classroom.exists?(access_code: candidate)
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    candidate
  end
end
