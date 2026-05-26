# lib/tasks/visual_regression.rake
#
# Visual regression baseline + after capture for feature B2a (Refonte atomes
# Button/Badge/Card). Re-runnable: same script captures pre-refacto baseline
# AND post-refacto "after" snapshots, by varying the output directory.
#
# Usage:
#   # Pre-refacto baseline
#   RAILS_ENV=development bin/rails 'visual_regression:capture[tmp/b2a-baseline-screenshots]'
#
#   # Post-refacto after (Task 8 of B2a)
#   RAILS_ENV=development bin/rails 'visual_regression:capture[tmp/b2a-after-screenshots]'
#
# Then diff with ImageMagick:
#   magick compare -metric AE -fuzz 2% \
#     tmp/b2a-baseline-screenshots/<name>.png \
#     tmp/b2a-after-screenshots/<name>.png \
#     /tmp/diff.png
#
# Targets (5 screens × {light,dark} where applicable, plus single-theme
# extras = ~9 PNG total):
#   - login_eleve          (light only)
#   - teacher_classrooms   (light + dark)
#   - student_subjects     (light + dark)
#   - design_preview       (light + dark)
#   - student_drawer_tibo  (light + dark)
#
# Conventions :
#   - Viewport 1440×900 desktop (same value asked by B2a spec).
#   - Selenium "viewport" screenshot (NOT full-page). Sufficient for SC-2:
#     we compare *baseline vs after* captured with the SAME method.
#     This intentionally differs from B1 T002 which used DevTools full-page;
#     B2a establishes its own captured-by-script baseline.
#   - Dark mode toggle: `document.documentElement.classList.add('dark')`
#     then short pause to let CSS variables resolve before snapshot.
#   - Auth via UI form (real Selenium browser; no Warden helpers because
#     the cookie would live in a different process).
#
# Seed data expected (db/seeds/development.rb) :
#   - Teacher: prof@test.com / password123
#   - Classroom: terminale-sin-2025 (tutor_free_mode_enabled)
#   - Student: anya.martineau / eleve123 (member of that classroom)
#   - At least one published subject with a question
#
# Tutor drawer (student_drawer_tibo) requires `OPENROUTER_API_KEY` to be set
# in the env when the seed ran (because the classroom relies on the teacher's
# server-side key in free-mode). If `@tutor_available` is false, the capture
# script logs a warning and skips that screen rather than failing the whole
# run.
#
# Bash discipline (CLAUDE.md): if invoking from a Claude session, pass an
# explicit timeout — Capybara boots Puma + Chrome on the first visit, which
# takes ~10s.

require "capybara"
require "capybara/dsl"
require "selenium-webdriver"

namespace :visual_regression do
  desc "Capture B2a visual baseline/after screenshots. Arg = output dir."
  task :capture, [ :output_dir ] => :environment do |_, args|
    output_dir = args[:output_dir].presence || "tmp/b2a-baseline-screenshots"
    full_output = Rails.root.join(output_dir)
    FileUtils.mkdir_p(full_output)

    abort "Run me with RAILS_ENV=development (got #{Rails.env})." unless Rails.env.development?

    capture = VisualRegressionCapture.new(full_output)
    capture.run
  end
end

class VisualRegressionCapture
  WIDTH  = 1440
  HEIGHT = 900

  def initialize(output_dir)
    @output_dir = output_dir
    configure_capybara
    @session = Capybara::Session.new(:b2a_headless_chrome, Rails.application)
    resize_window
    @results = []
  end

  def run
    puts "Capturing to #{@output_dir} (#{WIDTH}×#{HEIGHT})…"

    # 1. Login élève (no auth needed — public page)
    capture_login_eleve

    # 2. Teacher classrooms (light + dark)
    capture_teacher_classrooms

    # 3. Student subjects (light + dark)
    capture_student_subjects

    # 4. Design preview (light + dark) — needs teacher again
    capture_design_preview

    # 5. Student drawer Tibo (light + dark)
    capture_student_drawer_tibo

    puts "\nDone. #{@results.size} PNG written to #{@output_dir}:"
    @results.each { |path, size| puts "  #{File.basename(path)}  (#{size} bytes)" }
  ensure
    @session&.driver&.quit rescue nil
  end

  private

  def configure_capybara
    Capybara.app          = Rails.application
    Capybara.server       = :puma, { Threads: "4:4", Silent: true }
    Capybara.server_host  = "127.0.0.1"
    Capybara.app_host     = nil # let Capybara choose port
    Capybara.default_max_wait_time = 6

    Capybara.register_driver :b2a_headless_chrome do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      chrome_binary = [ "/usr/bin/chromium-browser", "/usr/bin/google-chrome", "/usr/bin/google-chrome-stable" ]
        .find { |p| File.exist?(p) }
      options.binary = chrome_binary if chrome_binary
      options.add_argument("--headless=new")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-gpu")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--window-size=#{WIDTH},#{HEIGHT}")
      options.add_argument("--hide-scrollbars")
      options.add_argument("--force-device-scale-factor=1")

      chromedriver_path = [ "/usr/bin/chromedriver", "/usr/local/bin/chromedriver" ]
        .find { |p| File.exist?(p) }
      driver_opts = { browser: :chrome, options: options }
      driver_opts[:service] = Selenium::WebDriver::Service.chrome(path: chromedriver_path) if chromedriver_path
      Capybara::Selenium::Driver.new(app, **driver_opts)
    end
  end

  def resize_window
    @session.visit("/up") # bootstraps Puma + Chrome
    @session.driver.browser.manage.window.resize_to(WIDTH, HEIGHT)
  end

  # ----- Per-screen captures -----

  def capture_login_eleve
    classroom = Classroom.find_by(access_code: "terminale-sin-2025")
    return warn("[skip] login_eleve: classroom terminale-sin-2025 missing — run db:seed") unless classroom

    student_logout
    teacher_logout
    @session.visit("/#{classroom.access_code}")
    # Page de login élève
    snapshot("login_eleve", theme: :light)
    # No dark variant (spec: light only).
  end

  def capture_teacher_classrooms
    teacher_login
    @session.visit("/teacher/classrooms")
    expect_path_or_warn("/teacher/classrooms")
    each_theme { |theme| snapshot("teacher_classrooms", theme: theme) }
  end

  def capture_student_subjects
    teacher_logout
    classroom, student = sin_classroom_and_student
    return warn("[skip] student_subjects: seed student missing") unless student

    student_login(classroom, student)
    @session.visit("/#{classroom.access_code}/subjects")
    each_theme { |theme| snapshot("student_subjects", theme: theme) }
  end

  def capture_design_preview
    student_logout
    teacher_login
    @session.visit("/teacher/design-system/preview")
    expect_path_or_warn("/teacher/design-system/preview")
    each_theme { |theme| snapshot("design_preview", theme: theme) }
  end

  def capture_student_drawer_tibo
    teacher_logout
    classroom, student = sin_classroom_and_student
    return warn("[skip] student_drawer_tibo: seed student missing") unless student

    subject   = classroom.subjects.where(status: :published).first
    return warn("[skip] student_drawer_tibo: no published subject for classroom") unless subject

    question = subject.all_parts.flat_map(&:questions).find { |q| q.validated? } ||
               subject.all_parts.flat_map(&:questions).first
    return warn("[skip] student_drawer_tibo: no question on subject") unless question

    student_login(classroom, student)
    @session.visit("/#{classroom.access_code}/subjects/#{subject.id}/questions/#{question.id}")

    # If tutor isn't available (no API key in env when seeded), warn + skip.
    unless @session.has_button?("Tibo", wait: 3) || @session.has_css?("[data-action*='tutor-activator#activate']", wait: 3)
      return warn("[skip] student_drawer_tibo: tutor button not present — OPENROUTER_API_KEY likely unset when seeding")
    end

    # Click whichever selector matches.
    begin
      @session.find("[data-action*='tutor-activator#activate']").click
    rescue Capybara::ElementNotFound
      @session.click_button("Tibo")
    end

    # Wait for drawer to appear (chat-drawer Stimulus controller).
    @session.has_css?("[data-controller~='chat-drawer'][data-chat-drawer-open-value='true'], #tutor-drawer.is-open, [data-chat-drawer-target='panel']:not(.hidden)", wait: 5)
    sleep 0.6 # let drawer animation settle

    each_theme { |theme| snapshot("student_drawer_tibo", theme: theme) }
  end

  # ----- Snapshot + theme -----

  def each_theme
    set_theme(:light); yield :light
    set_theme(:dark);  yield :dark
    set_theme(:light) # leave clean
  end

  def set_theme(theme)
    if theme == :dark
      @session.execute_script("document.documentElement.classList.add('dark')")
    else
      @session.execute_script("document.documentElement.classList.remove('dark')")
    end
    sleep 0.25 # let CSS variables + repaint settle
  end

  def snapshot(name, theme:)
    filename = "#{name}_#{theme}.png"
    path = File.join(@output_dir, filename)
    @session.save_screenshot(path)
    size = File.size(path)
    @results << [ path, size ]
    puts "  + #{filename}  (#{size} bytes)"
  end

  # ----- Auth helpers (real form POSTs, no Warden) -----

  def teacher_login
    @session.visit("/users/sign_in")
    return if @session.current_path == "/teacher" || @session.current_path == "/teacher/classrooms"

    @session.fill_in("Email", with: "prof@test.com")
    @session.fill_in("Mot de passe", with: "password123")
    @session.click_button("Se connecter")
    @session.has_no_current_path?("/users/sign_in", wait: 5)
  end

  def teacher_logout
    # Devise sign_out via DELETE /users/sign_out is the canonical path; UI link
    # might require JS. Use direct request instead.
    @session.driver.browser.manage.delete_all_cookies
  rescue StandardError
    nil
  end

  def student_login(classroom, student)
    @session.visit("/#{classroom.access_code}")
    @session.fill_in("Identifiant", with: student.username)
    @session.fill_in("Mot de passe", with: "eleve123")
    @session.click_button("Se connecter")
    @session.has_no_current_path?("/#{classroom.access_code}", wait: 5)
  end

  def student_logout
    @session.driver.browser.manage.delete_all_cookies
  rescue StandardError
    nil
  end

  def sin_classroom_and_student
    classroom = Classroom.find_by(access_code: "terminale-sin-2025")
    student   = classroom&.students&.find_by(username: "anya.martineau") || classroom&.students&.first
    [ classroom, student ]
  end

  def expect_path_or_warn(path)
    return if @session.current_path == path

    warn("  [warn] expected path #{path}, got #{@session.current_path}")
  end
end
