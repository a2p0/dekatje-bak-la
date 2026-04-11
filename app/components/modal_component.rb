class ModalComponent < ViewComponent::Base
  renders_one :body

  def initialize(title:, title_id: nil)
    @title = title
    @title_id = title_id || "modal-title-#{SecureRandom.hex(4)}"
  end
end
