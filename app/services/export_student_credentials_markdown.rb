class ExportStudentCredentialsMarkdown
  def self.call(classroom:)
    students = classroom.students.order(:last_name, :first_name)

    lines = []
    lines << "# Classe : #{classroom.name} #{classroom.school_year}"
    lines << "# Code d'accès : /#{classroom.access_code}"
    lines << ""
    lines << "| Nom | Identifiant | Mot de passe |"
    lines << "|-----|-------------|--------------|"

    students.each do |student|
      lines << "| #{student.last_name} #{student.first_name} | #{student.username} | _(à distribuer)_ |"
    end

    lines.join("\n")
  end
end
