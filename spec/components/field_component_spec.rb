require "rails_helper"

RSpec.describe FieldComponent, type: :component do
  # Reusable form builder backed by a real ActiveModel-ish stub so error
  # presence can be controlled per spec.
  let(:model_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      attribute :name, :string
      attribute :bio, :string
      attribute :specialty, :string
      attribute :pdf
      attribute :accepted, :boolean
    end
  end

  let(:model) { model_class.new }
  let(:form) { ActionView::Helpers::FormBuilder.new("user", model, view_context_double, {}) }

  # Minimal view context. ViewComponent provides `vc_test_controller` in tests
  # but we need a form builder. Easiest: render the component and let it
  # receive a real builder through the controller's view context.
  def view_context_double
    vc_test_controller.view_context
  end

  describe ":text type" do
    it "renders an <input type='text'> with B1 semantic classes" do
      render_inline(described_class.new(form: form, attribute: :name, label: "Nom"))
      expect(page).to have_css("input[type='text'][name='user[name]']")
      html = page.native.to_html
      expect(html).to include("bg-surface")
      expect(html).to include("text-on-surface")
      expect(html).to include("border-rule")
      expect(html).to include("rounded-lg")
      expect(html).to include("focus:ring-accent-secondary")
    end

    it "renders the label above the input with text-on-surface + font-semibold" do
      render_inline(described_class.new(form: form, attribute: :name, label: "Nom de la classe"))
      expect(page).to have_css("label.text-on-surface.font-semibold", text: "Nom de la classe")
    end

    it "renders the hint below the input when provided" do
      render_inline(described_class.new(form: form, attribute: :name, label: "Nom", hint: "Max 50 caractères"))
      expect(page).to have_css("p.text-on-surface-muted", text: "Max 50 caractères")
    end

    it "does not render a hint paragraph when hint is nil" do
      render_inline(described_class.new(form: form, attribute: :name, label: "Nom"))
      expect(page).not_to have_css("p.text-on-surface-muted")
    end

    it "renders error border + message when form.object has errors on the attribute" do
      model.errors.add(:name, "ne peut pas être vide")
      render_inline(described_class.new(form: form, attribute: :name, label: "Nom"))
      html = page.native.to_html
      expect(html).to include("border-danger")
      expect(page).to have_css("p.text-danger", text: "ne peut pas être vide")
    end

    it "renders hint AND error simultaneously when both are present" do
      model.errors.add(:name, "ne peut pas être vide")
      render_inline(described_class.new(form: form, attribute: :name, label: "Nom", hint: "Max 50 caractères"))
      expect(page).to have_css("p.text-danger", text: "ne peut pas être vide")
      expect(page).to have_css("p.text-on-surface-muted", text: "Max 50 caractères")
    end
  end

  describe ":textarea type" do
    it "renders a <textarea> with B1 semantic classes" do
      render_inline(described_class.new(form: form, attribute: :bio, label: "Biographie", type: :textarea))
      expect(page).to have_css("textarea[name='user[bio]']")
      html = page.native.to_html
      expect(html).to include("bg-surface")
      expect(html).to include("border-rule")
    end

    it "forwards :rows from options to the textarea" do
      render_inline(described_class.new(
        form: form, attribute: :bio, label: "Bio", type: :textarea,
        options: { rows: 6 }
      ))
      expect(page).to have_css("textarea[rows='6']")
    end

    it "applies error border + message when form.object has errors" do
      model.errors.add(:bio, "trop long")
      render_inline(described_class.new(form: form, attribute: :bio, label: "Bio", type: :textarea))
      html = page.native.to_html
      expect(html).to include("border-danger")
      expect(page).to have_css("p.text-danger", text: "trop long")
    end
  end

  describe ":select type" do
    let(:options_list) { [ [ "SIN", "SIN" ], [ "ITEC", "ITEC" ], [ "EE", "EE" ] ] }

    it "renders a <select> with the collection options" do
      render_inline(described_class.new(
        form: form, attribute: :specialty, label: "Spécialité",
        type: :select, collection: options_list
      ))
      expect(page).to have_css("select[name='user[specialty]']")
      expect(page).to have_css("option[value='SIN']", text: "SIN")
      expect(page).to have_css("option[value='ITEC']", text: "ITEC")
      expect(page).to have_css("option[value='EE']", text: "EE")
    end

    it "applies B1 semantic classes on the select" do
      render_inline(described_class.new(
        form: form, attribute: :specialty, label: "Spé",
        type: :select, collection: options_list
      ))
      html = page.native.to_html
      expect(html).to include("bg-surface")
      expect(html).to include("border-rule")
    end

    it "raises ArgumentError when collection is missing" do
      expect {
        described_class.new(form: form, attribute: :specialty, label: "Spé", type: :select)
      }.to raise_error(ArgumentError, /collection/)
    end
  end
end
