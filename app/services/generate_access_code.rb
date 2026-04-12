class GenerateAccessCode
  def self.call(...) = new(...).call

  def initialize(specialty:, school_year:)
    @specialty = specialty
    @school_year = school_year
  end

  def call
    base = [ @specialty, @school_year ].compact.join("-").parameterize
    candidate = base
    counter = 2

    while Classroom.exists?(access_code: candidate)
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    candidate
  end
end
