# Helper to read the compiled Tailwind CSS for token-presence assertions.
#
# Builds the file lazily if missing (first call triggers `bin/rails
# tailwindcss:build`). Used by `spec/lib/css_compiled_tokens_spec.rb`
# and `spec/lib/css_compiled_aliases_spec.rb`.
module CssTokenReader
  COMPILED_CSS_PATH = Rails.root.join("app/assets/builds/tailwind.css").freeze

  def read_compiled_css
    ensure_css_compiled!
    File.read(COMPILED_CSS_PATH)
  end

  private

  def ensure_css_compiled!
    return if File.exist?(COMPILED_CSS_PATH)

    Bundler.with_unbundled_env do
      system("bin/rails tailwindcss:build", chdir: Rails.root, exception: true)
    end
  end
end

RSpec.configure { |config| config.include CssTokenReader, type: :compiled_css } if defined?(RSpec)
