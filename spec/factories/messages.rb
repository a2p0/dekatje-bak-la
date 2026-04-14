# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    association :conversation
    role        { :user }
    content     { "Test message" }
    chunk_index { 0 }
  end
end
