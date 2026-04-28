class MatchExamSession
  def self.call(owner:, title:, year:) = new(owner:, title:, year:).call

  def initialize(owner:, title:, year:)
    @owner = owner
    @title = title&.strip
    @year  = year&.strip
  end

  def call
    return nil if @title.blank? || @year.blank?

    @owner.exam_sessions
          .where("LOWER(TRIM(title)) = ?", @title.downcase)
          .find_by(year: @year)
  end
end
