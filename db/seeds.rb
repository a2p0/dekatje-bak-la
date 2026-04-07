# frozen_string_literal: true

puts "=== Seeding DekatjeBakLa (#{Rails.env}) ==="

seed_file = Rails.root.join("db", "seeds", "#{Rails.env}.rb")

if seed_file.exist?
  load seed_file
else
  puts "  No seed file for #{Rails.env} environment (looked for #{seed_file})"
end

puts "=== Seed terminé ==="
