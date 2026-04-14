module Tutor
  Result = Data.define(:ok, :value, :error) do
    def self.ok(value = nil) = new(ok: true, value: value, error: nil)
    def self.err(error)      = new(ok: false, value: nil, error: error)
    def ok?  = ok
    def err? = !ok
  end
end
