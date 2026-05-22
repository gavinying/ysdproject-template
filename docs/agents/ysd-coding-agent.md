# YSD Coding Agent Guide

This guide captures reusable preferences for AI coding agents across repositories.
Keep repository-specific names, paths, scripts, URLs, and product details in each
project's own `AGENTS.md` or runbooks.

## Operating Principles

- Keep changes factual, scoped, and aligned with the current repository.
- Read the existing code and docs before deciding how to implement a change.
- Prefer established local patterns over new abstractions.
- When a task is not tied to product-specific business logic, follow the
  documented best practices of the library, framework, or platform in use before
  introducing custom workarounds.
- Treat planning docs as intent, not proof. Verify the current implementation
  before changing behavior or reporting status.
- Keep project-neutral foundation work separate from product-specific semantics.
- Add abstractions only when they remove real complexity, reduce meaningful
  duplication, or match an existing pattern in the codebase.

## Repository Orientation

When entering a repository:

- Identify the local agent guide, plan docs, architecture docs, testing docs, and
  release or operations runbooks.
- Use runbooks as the operational source of truth when they cover a task.
- Do not invent ad hoc test, release, deploy, rollback, or environment commands
  when a maintained runbook already exists.
- If a runbook conflicts with the current scripts or implementation, stop and
  report or fix the mismatch instead of guessing.
- Keep quick-reference notes short; put durable operational detail in the
  relevant runbook.
- Identify the supported environments before running commands. Most projects
  should distinguish local development, staging, and production, with separate
  env files, secrets, databases, deploy targets, and verification rules.

## Implementation Preferences

- Use typed contracts, shared schemas, generated types, and local API helpers
  where they exist.
- Avoid manual payload shape drift between client, server, database, and tests.
- Keep generated files and source files separate. Edit the source of truth, then
  regenerate or sync using the repository's documented workflow.
- Avoid direct edits to generated runtime config, generated API artifacts,
  vendored output, build output, or local machine state unless the task
  explicitly calls for it.
- Preserve user work in the git tree. Do not revert unrelated changes or
  generated local files unless explicitly asked.
- Keep imports, aliases, formatting, and file placement consistent with nearby
  code.
- Keep data models compact. Add tables, persistent resources, or new service
  boundaries only when a distinct lifecycle, permission boundary, query pattern,
  audit need, or scaling concern makes them necessary.
- Prefer configuration, enums, typed JSON, or existing tables for early
  variability when that matches the repository's design.
- Use consistent domain language from the repository's naming guide or existing
  UI/API copy.
- For locale-aware behavior, use precise locale naming such as `locale`,
  `default_locale`, `preferred_locale`, and `supported_locales` rather than vague
  language fields, unless the project already has a different convention.
- Store timestamps and date/time values according to the repository's established
  convention. Do not mix seconds, milliseconds, strings, and date objects without
  a clear boundary.

## Product And Foundation Boundaries

- Optimize for the product currently being built, not for hypothetical reuse.
- Use product-owned names and modules for product-specific behavior.
- Use generic names only when the code is genuinely reusable inside the current
  repository.
- When a product feature proves reusable, document the backport or extraction
  candidate separately before moving code into a shared foundation.
- Do not leak product-specific concepts into foundation docs or shared modules
  unless the task explicitly asks for that extraction.

## Testing And Verification

- Let verification scale with risk and blast radius.
- For narrow changes, run the smallest relevant checks that exercise the changed
  behavior.
- For shared contracts, auth, permissions, routing, settings, notifications,
  billing, data migrations, or user-facing workflows, add or update focused tests.
- When the user asks to make sure tests pass, use the repository's documented
  root validation target.
- Do not automatically run optional, destructive, headed, visual, billing,
  remote, or long-running suites unless the task requires them or the user asks.
- Before running browser or integration tests, make sure the documented local
  services, migrations, and seed data prerequisites are satisfied.
- Treat runtime log errors, failed health checks, and failed post-deploy probes as
  verification failures even when the test runner exits successfully.
- Keep production verification smoke-safe unless a production-safe runbook exists
  and the user explicitly approves broader checks.

Recommended testing structure:

- `test` should run automatic unit or workspace tests that do not need headed
  browsers, real payment flows, or production services.
- `test:smoke` should cover health checks and the smallest public/auth surface
  that proves the app is reachable.
- `test:integration` should cover API, Worker, backend, webhook, or contract
  behavior below full browser journeys.
- `test:e2e` should mean the essential or critical headless E2E suite. Keep it
  small enough to run routinely for major changes.
- `test:all` or `test:all:local` should compose the normal automatic gate:
  unit/workspace tests, smoke, integration, and essential E2E.
- `test:all:staging` should run the staging-safe remote matrix with staging env
  config and staging-safe helper behavior.
- `test:e2e:regression`, `test:e2e:visual`, `test:e2e:billing`,
  `test:e2e:backend`, and journey-specific E2E scripts should be on-demand
  suites for the relevant task, release, or incident.
- Billing, visual, headed, slow-motion, destructive, or real third-party E2E
  tests should never be hidden inside the default `test:e2e` lane.
- For major user-facing changes, verify at least unit/workspace tests, smoke, and
  essential E2E. Add integration or on-demand suites when the touched surface
  requires them.
- For Playwright-based projects, prefer named projects such as `smoke`,
  `integration`, `e2e-critical`, `e2e-regression`, `e2e-visual`, `e2e-billing`,
  and `e2e-backend` so script names map clearly to test scope.

## Environment And Infrastructure

- Edit environment source files, not generated runtime files.
- Use the repository's documented sync, encrypt, decrypt, and secret-push
  workflows.
- Keep app code, bindings, and environment references aligned with the
  infrastructure source of truth.
- Prefer infrastructure-as-code for persistent cloud resources. Avoid creating
  resources through dashboards or direct CLI commands unless the task explicitly
  calls for an emergency/manual change.
- Document any intentional infrastructure drift so it can be reconciled.
- Do not reuse unrelated secrets for new internal protocols or service-to-service
  authentication.

Environment setup preferences:

- Use explicit local/dev, staging, and production env files or secret stores.
  Avoid one shared env file for every target.
- Local/dev should favor emulators, local databases, local test helpers, and
  non-production credentials.
- Staging should mirror production topology where practical, but keep test
  helpers, demo seeding, and destructive verification explicitly staging-scoped.
- Production should not expose test helper routes, demo seeding, destructive
  checks, or broad E2E automation unless a production-safe runbook explicitly
  permits it.
- Generated runtime files should be recreated from env sources by documented
  `env:sync`-style commands.
- Secrets should move through documented encrypt/decrypt and
  `secret:push:<env>` workflows, not ad hoc copy-paste into generated files.
- Env-specific test commands should load env-specific files, for example a local
  matrix using local URLs and a staging matrix using staging URLs.

Cloudflare deployment preferences:

- Prefer Cloudflare Workers, Pages, Static Assets, D1, R2, KV, Queues, and related
  bindings to be declared in versioned config or infrastructure-as-code.
- Keep local, staging, and production Cloudflare resource names, bindings,
  secrets, routes, and databases distinct.
- Use explicit deploy scripts such as `deploy:staging` and `deploy:prod`; avoid a
  generic deploy command whose target is unclear.
- Run environment sync, secret push, migrations, deploy, health checks, and smoke
  checks in the order documented by the repository runbook.
- Do not run production migrations, deploys, or secret pushes unless the user
  explicitly asks or the approved runbook requires it.
- Treat Cloudflare dashboard changes and direct Wrangler resource creation as
  manual drift unless they are later reconciled into the repository's source of
  truth.
- For Cloudflare Workers, keep generated `wrangler` config and local `.dev.vars`
  files out of hand-edited source unless the repository intentionally uses them as
  source files.

## Package Script Naming

Prefer stable, predictable `package.json` script names across projects:

- `dev`, `build`, `lint`, `type-check`, and `test` for the standard local loop.
- `test:smoke`, `test:integration`, and `test:e2e` for automatic validation
  lanes.
- `test:all`, `test:all:local`, and `test:all:staging` for composed gates.
- `test:e2e:<scope>` for optional or focused browser suites, such as
  `test:e2e:regression`, `test:e2e:visual`, `test:e2e:billing`, and
  `test:e2e:backend`.
- `<area>:dev`, `<area>:build`, `<area>:lint`, `<area>:type-check`, and
  `<area>:test` for workspace areas such as backend, web, app, or docs.
- `db:migrate:<env>` and `db:seed:<env>` for database lifecycle commands.
- `env:sync`, `env:encrypt`, `env:decrypt`, and `secret:push:<env>` for env and
  secret workflows.
- `deploy:staging` and `deploy:prod` for deployment targets.

Script naming rules:

- Use colon-delimited names from broad to specific.
- Keep default script names safe and routine; put risky or slow behavior behind
  explicit suffixes.
- Make remote target names visible in the script name.
- Do not overload one script to behave differently based on hidden local state
  when separate explicit scripts would be clearer.
- If a command needs special prerequisites, document them near the script list or
  in the relevant runbook.

## Troubleshooting Discipline

- Diagnose from the observable failure first: command output, logs, network
  responses, database state, config, and recent code changes.
- Prefer permanent fixes over local-only workarounds.
- When fixing a bug, include a concise root-cause summary in the final handoff,
  along with the fix and verification performed.
- After major troubleshooting or an incident, create or update a takeaway in
  `docs/troubleshoot/` using snake_case naming.
- Troubleshooting writeups should include:
  - incident summary,
  - root cause,
  - permanent fix,
  - what to verify next time.
- For recurring operational failures, keep one canonical takeaway per issue area
  and append notes instead of creating duplicates.

## Git And Commits

- Check the worktree before editing.
- Assume unrelated local changes belong to the user.
- Keep commits scoped to the requested change.
- Use Conventional Commits when asked to commit:
  `<type>[optional scope]: <description>`.
- Common types include `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, `ci`,
  and `build`.
- Mark breaking changes with `!` in the type/scope or a `BREAKING CHANGE:`
  footer.

## Communication And Handoff

- Be direct, factual, and concise.
- State assumptions when they affect implementation or verification.
- Surface mismatches between docs, code, and scripts instead of silently choosing
  one.
- In final handoffs, summarize the change, root cause when relevant, and
  verification performed.
- If verification could not be run, say why and name the next best check.
- Avoid over-documenting routine work. Save detailed writeups for durable
  runbooks, troubleshooting notes, or decisions that future agents need.
