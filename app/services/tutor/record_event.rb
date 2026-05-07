module Tutor
  # Append-only writer of events to a Conversation's TutorState.
  # Atomic: re-reads, builds new state, persists in one update!.
  # Updates current_question_id only on navigated_here events.
  class RecordEvent
    ALLOWED_TYPES = %w[
      viewed_data_hints viewed_correction navigated_here
      student_attempt tutor_gave marked_done concept_seen
      cap_violation
    ].freeze

    ALLOWED_SOURCES = %w[page_click chip_click llm_message classifier code].freeze

    def self.call(conversation:, question_id:, type:, source:, **payload)
      new(
        conversation: conversation,
        question_id:  question_id,
        type:         type,
        source:       source,
        payload:      payload
      ).call
    end

    def initialize(conversation:, question_id:, type:, source:, payload:)
      @conversation = conversation
      @question_id  = question_id
      @type         = type.to_s
      @source       = source.to_s
      @payload      = payload
    end

    def call
      return Result.err("type interdit: #{@type}")     unless ALLOWED_TYPES.include?(@type)
      return Result.err("source interdite: #{@source}") unless ALLOWED_SOURCES.include?(@source)

      event = build_event
      Conversation.transaction do
        conv = Conversation.lock.find(@conversation.id)
        new_state = build_new_state(conv.tutor_state, event)
        conv.update!(tutor_state: new_state)
      end

      Result.ok(event: event)
    end

    private

    def build_event
      {
        "type"   => @type,
        "source" => @source,
        "at"     => Time.current.iso8601
      }.merge(@payload.transform_keys(&:to_s).compact)
    end

    def build_new_state(state, event)
      trace      = state.trace_for(@question_id)
      new_trace  = trace.append(event)
      new_state  = state.with_trace(new_trace)
      new_state  = new_state.with(current_question_id: @question_id) if @type == "navigated_here"

      if @type == "concept_seen" && @payload[:concept].present?
        new_state = new_state.with_concept(@payload[:concept])
      end

      new_state
    end
  end
end
