# GEMINI.md — DekatjeBakLa

## Project Overview
**DekatjeBakLa** ("décrocher le bac") is a web application for BAC exam training, specifically targeting STI2D students in Martinique. It automates the extraction of exam content from PDFs and provides AI-driven tutoring to students.

### Core Stack
- **Backend**: Ruby on Rails 8.1+ (Fullstack)
- **Frontend**: Hotwire (Turbo Streams, Stimulus), Tailwind CSS, ViewComponent
- **Database**: PostgreSQL (hosted on Neon)
- **Async Jobs**: Sidekiq + Redis
- **AI Integration**: Anthropic (PDF extraction), OpenRouter/OpenAI/Gemini (Student tutoring)
- **Storage**: ActiveStorage (local disk for PDFs)
- **Authentication**: Devise (Teachers) + Custom BCrypt (Students, email-less for GDPR)

### Key Architectural Patterns
- **Service Objects**: Business logic resides in `app/services/`, named as verbs (e.g., `ExtractQuestionsFromPdf`).
- **Thin Controllers**: Controllers handle request/response and delegate to services.
- **Contextual Tutoring**: A sticky panel provides persistent access to exam context while a streaming AI agent assists the student.
- **Data Hints**: Post-correction feedback points students to specific locations in technical documents (DT/DR).

---

## Building and Running

### Prerequisites
- Ruby 3.3+
- Node.js 18+
- PostgreSQL & Redis
- Anthropic API Key (for PDF extraction)

### Initial Setup
```bash
# Install dependencies
bundle install

# Setup environment variables (create .env from template if available)
# Required: DATABASE_URL, DATABASE_DIRECT_URL, REDIS_URL, ANTHROPIC_API_KEY

# Setup database
bin/rails db:prepare
```

### Running the Application
The easiest way to run the full development environment is using `bin/dev`, which starts the Rails server, Sidekiq worker, and Tailwind CSS watcher:
```bash
bin/dev
```

Alternatively, run components individually:
- **Rails Server**: `bin/rails s`
- **Sidekiq**: `bundle exec sidekiq`
- **Rails Console**: `bin/rails c`

---

## Testing
The project uses **RSpec** for testing.

```bash
# Run all tests
bundle exec rspec

# Run a specific test file
bundle exec rspec spec/models/user_spec.rb
```
- **Factories**: Managed by `factory_bot_rails`.
- **System Tests**: Capybara with Selenium.

---

## Development Conventions

### Git & Commits
We follow **Conventional Commits**:
- `feat(scope): ...`
- `fix(scope): ...`
- `refactor(scope): ...`
- `test(scope): ...`
- `docs(scope): ...`
- `chore(scope): ...`

### Coding Standards
- **Language**: Code, comments, and documentation are in **English**. The User Interface is in **French**.
- **Services**: All complex logic must be encapsulated in a Service Object in `app/services/`.
- **Soft Deletes**: Use `discarded_at` (via the `discard` gem pattern or manual implementation) for `Subject` and `Question` models.
- **Security**: Sensitive keys (like `api_key`) must be encrypted in the database using Rails' `encrypts` macro.
- **GDPR**: Do not collect student emails. Authentication is based on class-specific access codes and generated usernames.

### Database (Neon Specific)
- Use `DATABASE_URL` (pooled) for application connections.
- Use `DATABASE_DIRECT_URL` (direct) for running migrations.
