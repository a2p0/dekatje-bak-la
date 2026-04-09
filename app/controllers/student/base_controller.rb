class Student::BaseController < ApplicationController
  layout "student"

  before_action :require_student_auth
  before_action :set_classroom_from_url

  helper_method :current_student

  private

  def current_student
    @current_student ||= ::Student.find_by(id: session[:student_id])
  end

  def require_student_auth
    unless current_student && current_student.classroom.access_code == params[:access_code]
      session.delete(:student_id)
      redirect_to student_login_path(access_code: params[:access_code]),
                  alert: "Veuillez vous connecter."
    end
  end

  def set_classroom_from_url
    @classroom = Classroom.find_by(access_code: params[:access_code])
    redirect_to root_path, alert: "Classe introuvable." unless @classroom
  end
end
