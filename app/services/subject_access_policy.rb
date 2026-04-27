class SubjectAccessPolicy
  def self.full_access?(subject, classroom)
    return false if subject.tronc_commun?
    subject.specialty.to_s.upcase == classroom.specialty.to_s.upcase
  end

  def self.tc_only?(subject, classroom)
    !full_access?(subject, classroom)
  end

  def self.accessible_parts(parts, subject, classroom)
    return parts if full_access?(subject, classroom)
    parts.select { |p| p.common? }
  end
end
