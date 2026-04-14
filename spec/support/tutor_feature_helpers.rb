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

RSpec.configure do |config|
  config.around(:each, tutor_streaming: true) do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end
end
