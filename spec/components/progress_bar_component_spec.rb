require "rails_helper"

RSpec.describe ProgressBarComponent, type: :component do
  it "renders the progress bar" do
    render_inline(described_class.new(current: 7, total: 18))

    expect(page).to have_css("[role='progressbar']")
    expect(page).to have_css("[aria-valuenow='7']")
    expect(page).to have_css("[aria-valuemax='18']")
  end

  it "renders the text label" do
    render_inline(described_class.new(current: 7, total: 18, show_text: true))

    expect(page).to have_text("7/18")
    expect(page).to have_text("39%")
  end

  it "handles zero total" do
    render_inline(described_class.new(current: 0, total: 0))

    expect(page).to have_css("[aria-valuenow='0']")
  end
end