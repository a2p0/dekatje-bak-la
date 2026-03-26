<!-- Sync Impact Report
Version change: 0.0.0 → 1.0.0
Added sections: Core Principles, RGPD & Security, Definition of Done, Governance
Templates requiring updates: ✅ constitution.md populated from speckit/constitution.md
-->

# DekatjeBakLa Constitution

## Core Principles

### I. Fullstack Rails — Hotwire Only
Rails 8 fullstack MUST be used exclusively. Hotwire/Turbo Streams handles all interactivity.
No SPA framework (Vue, React) unless isolated to a specific page island.
All AI calls MUST originate from the Rails server — never from the browser.
One Coolify deployment for the Rails app. Redis and Neon are external services.

### II. RGPD & Protection des mineurs (NON-NEGOTIABLE)
No open registration. Teachers MUST create all student accounts.
No student email MUST ever be collected or stored.
Students authenticate via username + password only (no email).
Student data MUST be isolated to their classroom.
A privacy policy page is mandatory before production deployment.

### III. Security
API keys (teacher and student) MUST be encrypted with Rails native `encrypts`.
`RAILS_MASTER_KEY` MUST never appear in versioned code.
No secret MUST ever appear in logs.
The server fallback key (`ANTHROPIC_API_KEY`) MUST never be exposed to the client.

### IV. Test-First (NON-NEGOTIABLE)
TDD is mandatory: RSpec test written and failing BEFORE production code.
Thin controllers: all logic MUST live in `app/services/`.
Migrations MUST be written and validated before ActiveRecord models.
One Pull Request = one feature = one branch.

### V. Performance & Simplicity (contexte Martinique)
Interface MUST be lightweight. Assets compiled locally — no external CDN.
AI call timeout: minimum 60 seconds.
PDF limits: 20 MB (subjects), 50 MB (lessons).
Soft delete on Subject and Question (`discarded_at`) — never hard delete.

## RGPD & Security Requirements

Student data isolation: each student session MUST be scoped to their classroom.
Encrypted storage: `encrypts :api_key` for both User and Student models.
No logging of API keys, passwords, or personal data.
Two distinct Neon URLs: pooled (app) and direct (migrations only).

## Definition of Done

A feature is complete when:
1. RSpec tests pass (unit + integration)
2. Migration is clean and reversible (`db:rollback` works)
3. Interface works on Chrome and Firefox
4. No API key or secret appears in logs
5. RGPD: no unnecessary student data collected
6. Interface copy is in French; code (variables, methods, routes) is in English

## Governance

This constitution supersedes all other development practices.
Amendments require: documentation in DECISIONS.md, rationale, and migration plan if applicable.
All PRs must verify compliance with these principles before merge.
The constitution MUST be reviewed at each major milestone (F1→F10 completion).

**Version**: 1.0.0 | **Ratified**: 2026-03-26 | **Last Amended**: 2026-03-26
