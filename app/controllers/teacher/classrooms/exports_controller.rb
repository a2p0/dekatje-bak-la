class Teacher::Classrooms::ExportsController < Teacher::BaseController
  before_action :set_classroom

  def show
    respond_to do |format|
      format.pdf do
        pdf = ExportStudentCredentialsPdf.call(classroom: @classroom)
        send_data pdf.render,
                  filename: "fiches-connexion-#{@classroom.access_code}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
      format.markdown do
        markdown = ExportStudentCredentialsMarkdown.call(classroom: @classroom)
        send_data markdown,
                  filename: "fiches-connexion-#{@classroom.access_code}.md",
                  type: "text/markdown",
                  disposition: "attachment"
      end
    end
  end

  private

  def set_classroom
    @classroom = current_user.classrooms.find(params[:classroom_id])
  end
end
