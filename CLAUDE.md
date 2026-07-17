# The Ipalibos — Claude Code Project Instructions

You are building **The Ipalibos**, a cross-platform family management app (iOS + Android, plus web/tablet) for the Ipalibo family: shared calendar, chores/routines with automatic reminders and completion tracking, family chat, GPS safety, parental controls with device unlock workflow, rewards, homework/reading tracking, and reports.

Read the docs in this order before writing code:

1. `docs/01-product-spec.md` — vision, roles, permission matrix, and the full functional spec for all 14 modules (source of truth for *what* to build)
2. `docs/02-data-model.md` — Postgres schema (Supabase) covering every module
3. `docs/03-architecture.md` — tech stack, API standards, auth, security, folder structure
4. `docs/04-design-system.md` — colours, type scale, spacing, component tokens, screen inventory
5. `docs/05-build-sequence.md` — technical dependency order (not a priority ranking — every module in `01-product-spec.md` is in scope) plus setup commands and definition-of-done per module

There is also `reference/family-board.html` — an earlier throwaway HTML prototype of the calendar/chores flow. It's useful for interaction reference only; it is not the architecture (no localStorage, no backend) and should not be ported directly.

## Non-negotiable decisions (do not re-litigate without asking)

- **Framework: Flutter**, single codebase targeting iOS, Android, and web. (`02-architecture.md` explains why over React Native / separate native apps.)
- **Backend: Supabase** (Postgres, Auth, Realtime, Storage, Edge Functions). Push via FCM (Android) + APNs (iOS), bridged through Supabase Edge Functions.
- **State management: Riverpod.** Routing: `go_router`.
- **Every table has `family_id` and Row Level Security is mandatory** — a Parent or Child must only ever see their own family's rows. Write RLS policies alongside the migration that creates the table, not after.
- Two roles only for v1: `parent`, `child`. Design the permission checks as a single `hasPermission(user, action)` helper backed by the matrix in `01-product-spec.md`, not scattered role checks.
- iOS device restriction/unlock must go through Apple's **Family Controls / Screen Time API** only. Do not attempt full-device lock or anything Apple would reject at review — flag it and ask if a requirement can't be done this way.
- Treat every child-related data flow (GPS, chat, device data) as subject to child-privacy requirements (COPPA-style handling, parental consent, data minimisation, exportable/deletable data). See "Compliance notes" in `01-product-spec.md` §Security.

## Working conventions

- One module = one feature folder under `lib/features/<module>/` (data / domain / presentation split).
- Every new table ships with: migration SQL, RLS policy, Riverpod repository + provider, and at least one widget test.
- Don't invent endpoints or fields that aren't in `02-data-model.md` or `03-architecture.md` — extend those docs first, then implement, so the docs stay the source of truth.
- Ask before starting GPS background tracking, chat, or device-restriction code — these need platform entitlements/App Store or Play Store review setup (accounts, capability toggles, privacy manifests) that a human has to do outside this repo first.
- When a spec section is ambiguous or platform capability limits what's described (this happens most in Parental Controls and GPS), implement the closest compliant version and note the deviation in `docs/06-deviations.md` (create it the first time it's needed).
