class ExtractionJob < ApplicationRecord
  belongs_to :subject
  belongs_to :exam_session, optional: true

  enum :status,        { pending: 0, processing: 1, done: 2, failed: 3 }
  enum :provider_used, { teacher: 0, server: 1 }
end
