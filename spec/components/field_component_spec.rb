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

  describe ":file type" do
    it "renders an <input type='file'> with file:-prefixed Tailwind classes for the button look" do
      render_inline(described_class.new(form: form, attribute: :pdf, label: "PDF", type: :file))
      expect(page).to have_css("input[type='file'][name='user[pdf]']")
      html = page.native.to_html
      expect(html).to include("file:bg-accent-secondary/15")
      expect(html).to include("file:text-accent-secondary")
    end

    it "forwards :accept from options" do
      render_inline(described_class.new(
        form: form, attribute: :pdf, label: "PDF", type: :file,
        options: { accept: "application/pdf" }
      ))
      expect(page).to have_css("input[accept='application/pdf']")
    end
  end

  describe ":checkbox type" do
    it "renders <input type='checkbox'> inside an inline <label>" do
      render_inline(described_class.new(form: form, attribute: :accepted, label: "J'accepte", type: :checkbox))
      expect(page).to have_css("label.flex.items-center input[type='checkbox'][name='user[accepted]']")
      expect(page).to have_css("label", text: "J'accepte")
    end

    it "applies accent-accent-primary on the checkbox" do
      render_inline(described_class.new(form: form, attribute: :accepted, label: "X", type: :checkbox))
      html = page.native.to_html
      expect(html).to include("accent-accent-primary")
    end

    it "shows the error message below when form.object has errors" do
      model.errors.add(:accepted, "obligatoire")
      render_inline(described_class.new(form: form, attribute: :accepted, label: "X", type: :checkbox))
      expect(page).to have_css("p.text-danger", text: "obligatoire")
    end

    it "silently suppresses the hint paragraph (label is inline next to checkbox)" do
      # Deliberate UX choice: the label sits inline with the checkbox so a hint
      # paragraph would be visually redundant. Lock this behavior so a future
      # refactor doesn't accidentally re-render the hint.
      render_inline(described_class.new(
        form: form, attribute: :accepted, label: "X", type: :checkbox,
        hint: "ne sera pas rendu"
      ))
      expect(page).not_to have_css("p.text-on-surface-muted")
      expect(page).not_to have_text("ne sera pas rendu")
    end
  end

  describe ":file_dropzone type" do
    it "renders a <label> wrapper with dashed border and the sr-only file input inside" do
      render_inline(described_class.new(form: form, attribute: :pdf, label: "PDF", type: :file_dropzone))
      # The <label> wrapper is the clickable area.
      expect(page).to have_css("label.border-dashed.border-rule.bg-surface-raised")
      # The actual file input is inside, marked sr-only.
      expect(page).to have_css("label input[type='file'].sr-only", visible: :all)
    end

    it "shows the fixed 'Déposer un fichier' text in accent-secondary" do
      render_inline(described_class.new(form: form, attribute: :pdf, label: "PDF", type: :file_dropzone))
      expect(page).to have_css("div.text-accent-secondary.font-semibold", text: "Déposer un fichier")
    end

    it "shows the hint as the secondary line when provided" do
      render_inline(described_class.new(
        form: form, attribute: :pdf, label: "PDF", type: :file_dropzone,
        hint: "PDF uniquement · max 20 Mo"
      ))
      expect(page).to have_css("div.text-on-surface-muted", text: "PDF uniquement · max 20 Mo")
    end

    it "embeds an SVG upload icon" do
      render_inline(described_class.new(form: form, attribute: :pdf, label: "PDF", type: :file_dropzone))
      expect(page).to have_css("label svg", visible: :all)
    end

    it "forwards :accept from options to the file input" do
      render_inline(described_class.new(
        form: form, attribute: :pdf, label: "PDF", type: :file_dropzone,
        options: { accept: "application/pdf" }
      ))
      expect(page).to have_css("label input[type='file'][accept='application/pdf']", visible: :all)
    end
  end
end
