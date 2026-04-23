require "rails_helper"

RSpec.describe ModalComponent, type: :component do
  it "renders a modal with title" do
    render_inline(described_class.new(title: "Confirmer")) do |modal|
      modal.with_body { "Êtes-vous sûr ?" }
    end

    expect(page).to have_text("Confirmer")
    expect(page).to have_text("Êtes-vous sûr ?")
    expect(page).to have_css("[role='dialog']")
  end
end
