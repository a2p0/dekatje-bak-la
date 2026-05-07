# Runs ProcessTutorMessageJob inline (not just enqueued) so that
# broadcasts emitted by Tutor::CallLlm and Tutor::BroadcastMessage
# actually fire during a Capybara scenario.
#
# Opt-in via `tutor_streaming: true` metadata on the example/group:
#
#   scenario "tuteur répond ...", js: true, tutor_streaming: true do
#     ...
#   end
#
# The test adapter for ActionCable is configured via config/cable.yml
# (test: adapter: async) — no spec-level toggling needed there.

module TutorFeatureHelpers
  def open_tutor_drawer
    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click
    expect(page).to have_css("[data-chat-drawer-target='drawer'].translate-x-0", visible: :all, wait: 5)
  end
end

RSpec.configure do |config|
  config.around(:each, tutor_streaming: true) do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  config.include TutorFeatureHelpers, type: :feature
end
