class Teacher::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_confirmed!

  helper_method :current_teacher

  private

  def current_teacher
    current_user
  end

  def require_confirmed!
    return if current_user.confirmed?

    sign_out current_user
    redirect_to new_user_session_path,
                alert: "Veuillez confirmer votre adresse email avant de vous connecter."
  end
end
