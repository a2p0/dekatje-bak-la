module PartsHelper
  def common_parts(parts)
    parts.select { |p| p.section_type == "common" }
  end

  def specific_parts(parts)
    parts.select { |p| p.section_type == "specific" }
  end

  def parts_in_same_section(parts, reference_part)
    parts.select { |p| p.section_type == reference_part.section_type }
  end
end
