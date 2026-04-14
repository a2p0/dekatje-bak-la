module Tutor
  class NoApiKeyError < StandardError
    def initialize(msg = "Aucune clé API disponible pour le tutorat.")
      super
    end
  end
end
