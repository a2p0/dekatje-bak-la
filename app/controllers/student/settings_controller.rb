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

  private

  def settings_params
    params.require(:student).permit(:default_mode, :api_provider, :api_model, :api_key, :specialty)
  end
end
