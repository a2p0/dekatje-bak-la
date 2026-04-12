class Student::SettingsController < Student::BaseController
  def show
    @models_json = Student::AVAILABLE_MODELS.to_json
  end

  def update
    if current_student.update(settings_params)
      redirect_to student_settings_path(access_code: params[:access_code]),
                  notice: "Réglages enregistrés."
    else
      @models_json = Student::AVAILABLE_MODELS.to_json
      render :show, status: :unprocessable_entity
    end
  end

  def test_key
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

  private

  def settings_params
    params.require(:student).permit(:default_mode, :api_provider, :api_model, :api_key, :specialty)
  end
end
