class DataHintsComponent < ViewComponent::Base
  def initialize(data_hints:)
    @data_hints = data_hints
  end

  def render?
    @data_hints.any?
  end
end
