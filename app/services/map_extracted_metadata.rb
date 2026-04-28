class MapExtractedMetadata
  SPECIALTY_VALUES = %w[sin itec ee ac].freeze
  EXAM_VALUES      = %w[bac bts autre].freeze
  REGION_VALUES    = %w[metropole reunion polynesie candidat_libre].freeze
  VARIANTE_VALUES  = %w[normale remplacement].freeze

  def self.call(raw_json) = new(raw_json).call

  def initialize(raw_json)
    parsed = parse(raw_json)
    @meta  = (parsed || {}).fetch("metadata", {})
  end

  def call
    {
      title:    string_or_nil(@meta["title"]),
      year:     string_or_nil(@meta["year"]),
      exam:     enum_or_nil(@meta["exam"], EXAM_VALUES),
      specialty: enum_or_nil(@meta["specialty"], SPECIALTY_VALUES),
      region:   enum_or_nil(@meta["region"], REGION_VALUES),
      variante: enum_or_nil(@meta["variante"], VARIANTE_VALUES)
    }
  end

  private

  def parse(raw)
    return {} if raw.nil?
    return raw if raw.is_a?(Hash)

    json_str = raw.to_s.gsub(/\A```(?:json)?\s*|\s*```\z/, "").strip
    JSON.parse(json_str)
  rescue JSON::ParserError
    {}
  end

  def string_or_nil(val)
    val.presence&.strip
  end

  def enum_or_nil(val, allowed)
    normalized = val.to_s.downcase.strip
    normalized if allowed.include?(normalized)
  end
end
