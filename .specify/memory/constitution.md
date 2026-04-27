<!-- Sync Impact Report
Version change: 2.0.0 → 2.1.0
Modified principles:
  - VI "Development Workflow" — added rules 8-11 (superpowers skills integration)
Added sections: none
Removed sections: none
Templates requiring updates: none
Follow-up TODOs: none
-->

# DekatjeBakLa Constitution

## Core Principles

### I. Fullstack Rails — Hotwire Only

Rails 8 fullstack MUST be used exclusively. Hotwire/Turbo Streams
handles all interactivity. No SPA framework (Vue, React) unless
isolated to a specific page island.
All AI calls MUST originate from the Rails server — never from the
browser.
One Coolify deployment for the Rails app. Redis and Neon are external
services.

### II. RGPD & Protection des mineurs (NON-NEGOTIABLE)

No open registration. Teachers MUST create all student accounts.
No student email MUST ever be collected or stored.
Students authenticate via username + password only (no email).
Student data MUST be isolated to their classroom.
A privacy policy page is mandatory before production deployment.

### III. Security

API keys (teacher and student) MUST be encrypted with Rails native
`encrypts`.
`RAILS_MASTER_KEY` MUST never appear in versioned code.
No secret MUST ever appear in logs.
The server fallback key (`ANTHROPIC_API_KEY`) MUST never be exposed
to the client.

### IV. Testing (NON-NEGOTIABLE)

TDD is mandatory: RSpec test written and failing BEFORE production
code.
Feature specs (Capybara) MUST be written for every user-facing
behavior.
Unit specs MUST be written for every service object.
Migrations MUST be written and validated before ActiveRecord models.

CI validation via GitHub Actions is the authoritative test runner.
Local test execution is a temporary workaround — the development
machine is too slow for Selenium/Capybara feature specs. This
constraint MAY be lifted when hardware is upgraded.

### V. Performance & Simplicity (contexte Martinique)

Interface MUST be lightweight. Assets compiled locally — no external
CDN.
AI call timeout: minimum 60 seconds.
PDF limits: 20 MB (subjects), 50 MB (lessons).
Soft delete on Subject and Question (`discarded_at`) — never hard
delete.
Always prefer simple, readable code over performance optimizations
(MVP context).

### VI. Development Workflow (NON-NEGOTIABLE)

**Before any action**, the assistant MUST consult the constitution and
memory feedbacks.

1. **Never code without explicit user request.** Present
   analysis/plan and wait for explicit go-ahead ("code", "fais-le",
   "implémente", "on y va"). Do not interpret "ok" as permission to
   code. When in doubt, ask.

2. **Always propose a plan before coding**, even for a 2-line bugfix.
   The plan can be short but MUST exist and be validated by the user.

3. **Choose workflow by change type:**

   | Type | First check | Workflow |
   |---|---|---|
   | Feature | — | speckit: specify → plan → tasks → analyze |
   | Refactoring | — | speckit: specify → plan → tasks → analyze |
   | Bugfix | Are specs impacted or missing? If yes → speckit. If no ↓ | diagnostic → present fix → wait for OK → implement |
   | UX tweak | Are specs impacted or missing? If yes → speckit. If no ↓ | present change → wait for OK → implement |
   | Config/infra | Are specs impacted or missing? If yes → speckit. If no ↓ | present change → wait for OK → implement |

4. **Feature branch systematic.** Never commit directly on main.

5. **PR systematic before merge.** Never merge directly on main.

6. **One concern per commit.** Separate unrelated changes into
   distinct commits.

7. **Push + CI green after each coherent batch.** Never accumulate
   unrelated changes without CI validation between them.

8. **Debugging** : invoke `systematic-debugging` before any fix —
   root cause first, never patch without investigation.

9. **Verification** : invoke `verification-before-completion` before
   any "done" claim — run tests, read output, THEN assert success.

10. **Branch completion** : invoke `finishing-a-development-branch`
    before opening a PR — tests green, then present merge/PR/keep/discard
    options.

11. **Parallel agents** : invoke `dispatching-parallel-agents` when
    2+ independent tasks exist (e.g. specs on different files, bugs
    with unrelated root causes).

## RGPD & Security Requirements

Student data isolation: each student session MUST be scoped to their
classroom.
Encrypted storage: `encrypts :api_key` for both User and Student
models.
No logging of API keys, passwords, or personal data.
Two distinct Neon URLs: pooled (app) and direct (migrations only).

## Definition of Done

A feature is complete when:
1. Plan validated by the user before implementation
2. RSpec tests pass (unit + integration)
3. Migration is clean and reversible (`db:rollback` works)
4. Dedicated feature branch created
5. PR created and CI green
6. Interface works on Chrome and Firefox
7. No API key or secret appears in logs
8. RGPD: no unnecessary student data collected
9. Interface copy is in French; code (variables, methods, routes) is
   in English

## Governance

This constitution supersedes all other development practices.
The assistant MUST consult this constitution AND memory feedbacks
before taking any action.
Amendments require: documentation in DECISIONS.md, rationale, and
migration plan if applicable.
All PRs must verify compliance with these principles before merge.
The constitution MUST be reviewed at each major milestone.

**Version**: 2.1.0 | **Ratified**: 2026-03-26 | **Last Amended**: 2026-04-27
