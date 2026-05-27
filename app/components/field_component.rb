class FieldComponent < ViewComponent::Base
  # Form-builder-aware input wrapper with label, hint, and error rendering.
  # Six supported types: :text, :textarea, :file, :file_dropzone, :select, :checkbox.
  # All inputs consume B1 semantic tokens (no hardcoded Tailwind color utilities).
  #
  # Adoption: zero consumers in B2b — see roadmap B5 for view migration away
  # from the DEPRECATED partial app/views/teacher/shared/_field.html.erb.

  SUPPORTED_TYPES = %i[text textarea file file_dropzone select checkbox].freeze

  # Tailwind classes applied to text/textarea/select/file/checkbox inputs.
  # :file_dropzone uses a different markup (label wrapper) so does not use this.
  BASE_INPUT_CLASSES = "w-full bg-surface text-on-surface border border-rule " \
                       "rounded-lg px-3 py-2 text-sm " \
                       "focus:outline-none focus:ring-2 focus:ring-accent-secondary " \
                       "focus:border-accent-primary " \
                       "disabled:opacity-60 disabled:cursor-not-allowed".freeze

  def initialize(form:, attribute:, label:, type: :text, hint: nil,
                 collection: nil, options: {})
    @form       = form
    @attribute  = attribute.to_sym
    @label      = label
    @type       = type.to_sym
    @hint       = hint
    @collection = collection
    @options    = options

    raise ArgumentError, "FieldComponent: unknown type :#{@type}" unless SUPPORTED_TYPES.include?(@type)
    raise ArgumentError, "FieldComponent: :select requires a collection" if @type == :select && @collection.nil?
  end

  def has_error?
    @form.object.respond_to?(:errors) && @form.object.errors[@attribute].any?
  end

  def error_messages
    return [] unless has_error?

    @form.object.errors[@attribute]
  end

  def input_classes
    extra = has_error? ? " border-danger" : ""
    BASE_INPUT_CLASSES + extra
  end

  # Merge user-supplied options with our class string. User classes win on conflict.
  def merged_options(extra_class: input_classes)
    user_class = @options[:class]
    merged_class = [ extra_class, user_class ].compact.join(" ")
    @options.merge(class: merged_class)
  end

  attr_reader :form, :attribute, :label, :type, :hint, :collection, :options
end
