class Student::SessionsController < ApplicationController
  before_action :set_classroom

  def new
    redirect_to student_root_path(access_code: params[:access_code]) if current_student_in_classroom?
  end

  def create
    student = AuthenticateStudent.call(
      access_code: params[:access_code],
      username: params[:username],
      password: params[:password]
    )

    if student
      session[:student_id] = student.id
      redirect_to student_root_path(access_code: params[:access_code]),
                  notice: "Bienvenue, #{student.first_name} !"
    else
      flash.now[:alert] = "Identifiant ou mot de passe incorrect."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:student_id)
    redirect_to student_login_path(access_code: params[:access_code]),
                notice: "Vous êtes déconnecté."
  end

  private

  def set_classroom
    @classroom = Classroom.find_by(access_code: params[:access_code])
    redirect_to root_path, alert: "Classe introuvable." unless @classroom
  end

  def current_student_in_classroom?
    student = ::Student.find_by(id: session[:student_id])
    student&.classroom == @classroom
  end
end
