require "prawn"
require "prawn/table"

class ExportStudentCredentialsPdf
  def self.call(classroom:)
    students = classroom.students.order(:last_name, :first_name)

    Prawn::Document.new(page_size: "A4") do |pdf|
      pdf.font_size 12

      pdf.text "Classe : #{classroom.name} #{classroom.school_year}", size: 16, style: :bold
      pdf.text "Code d'accès élèves : /#{classroom.access_code}"
      pdf.move_down 10

      table_data = [ [ "Nom", "Identifiant", "Mot de passe" ] ]
      students.each do |student|
        table_data << [ "#{student.last_name} #{student.first_name}", student.username, "" ]
      end

      pdf.table(table_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = "DDDDDD"
        self.cell_style = { padding: [ 6, 8 ] }
      end
    end
  end
end
