# Rate limit the tutor message endpoint to protect against runaway
# client loops and abuse of the free-mode teacher key.
#
# Throttle key: student_id (read from the Rails session) if present,
# otherwise IP — so a shared school IP cannot lock everyone out while
# still bounding unauthenticated traffic.

class Rack::Attack
  throttle("tutor/messages/student", limit: 10, period: 1.minute) do |req|
    if req.post? && req.path.match?(%r{/conversations/\d+/messages\z})
      req.session["student_id"] || req.ip
    end
  end

  throttle("req/ip", limit: 300, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/assets", "/cable")
  end

  self.throttled_responder = lambda do |_req|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "Trop de requêtes. Attends une minute avant d'envoyer un nouveau message." }.to_json ]
    ]
  end
end
