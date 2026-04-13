class Student::Settings::ApiKeyTestsController < Student::BaseController
  def create
    ValidateStudentApiKey.call(
      provider: params[:provider],
      api_key: params[:api_key],
      model: params[:model]
    )

    render turbo_stream: turbo_stream.replace(
      "test_key_result",
      html: '<p id="test_key_result" style="color: #22c55e; font-size: 13px; margin-top: 8px;">✓ Clé valide — connexion réussie.</p>'.html_safe
    )
  rescue ValidateStudentApiKey::InvalidApiKeyError => e
    render turbo_stream: turbo_stream.replace(
      "test_key_result",
      html: "<p id=\"test_key_result\" style=\"color: #ef4444; font-size: 13px; margin-top: 8px;\">✗ #{ERB::Util.html_escape(e.message)}</p>".html_safe
    )
  end
end
