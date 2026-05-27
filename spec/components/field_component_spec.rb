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
end
