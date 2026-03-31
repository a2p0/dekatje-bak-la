require "rails_helper"

RSpec.describe CardComponent, type: :component do
  it "renders with body content" do
    render_inline(described_class.new) do |card|
      card.with_body { "Hello world" }
    end

    expect(page).to have_text("Hello world")
    expect(page).to have_css("div.rounded-lg")
    expect(page).to have_css("div.border")
  end

  it "renders header, body, and footer" do
    render_inline(described_class.new) do |card|
      card.with_header { "Title" }
      card.with_body { "Content" }
      card.with_footer { "Footer" }
    end

    expect(page).to have_text("Title")
    expect(page).to have_text("Content")
    expect(page).to have_text("Footer")
    expect(page).to have_css("div.border-t")
  end

  it "renders without footer when not provided" do
    render_inline(described_class.new) do |card|
      card.with_body { "Content only" }
    end

    expect(page).to have_text("Content only")
    expect(page).not_to have_css("div.border-t")
  end
end
