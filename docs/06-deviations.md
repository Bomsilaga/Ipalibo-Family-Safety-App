# The Ipalibos — Deviations from Spec

Created per `CLAUDE.md`: "When a spec section is ambiguous or platform
capability limits what's described ... implement the closest compliant
version and note the deviation here." Also used for schema/architecture
extensions made during implementation, per CLAUDE.md's "extend those docs
first, then implement" rule — those docs (`02-data-model.md` etc.) are
already updated; this file just explains why.

## Module 1 (Foundation)

### `family_invites` table added

`01-product-spec.md` §4 describes a "Family invitation" flow (parent
invites by email/phone/link) but `02-data-model.md` had no backing table.
Added `family_invites` (migration
`supabase/migrations/20260717000002_family_invites.sql`, documented in
`02-data-model.md`) to give it one.

**Why not a direct client insert into `users` for joining an existing
family:** the RLS "founder bootstrap" policy on `users` only allows a
brand-new authenticated user to insert their own row when they're the
*first* member of a family (see `enforce_users_guardrails` and the insert
policy in `20260717000001_init_core_tables.sql`). Allowing any
authenticated stranger to insert themselves into an *existing* family by
just knowing/guessing its `family_id` would be a serious data-exposure
bug — nothing about "authenticated" implies "invited." Invite acceptance
is deferred to a future `accept-invite` Edge Function (service role,
validates the invite token against `family_invites.token_hash` before
inserting) — not yet implemented; `family_invites` rows can currently be
created and listed by parents, but there's no accept flow yet.

### Child accounts require a Supabase Edge Function, not a plain client insert

`public.users.id` references `auth.users(id)`, and children "do not
self-register" (`01-product-spec.md` §4). Something still has to create
their `auth.users` identity, and only the service role can call the Admin
API to do that without an email/password login. Added
`supabase/functions/create-child-account` (service role; verifies the
caller is an authenticated parent server-side, then creates the child's
auth identity and `public.users` row together, rolling back the auth
identity if the second insert fails). Children authenticate afterwards via
PIN/biometric against an already-registered family device session, per the
product spec — the placeholder email minted for the Admin API call is
never used for login.

### `sqlite3` pinned below 3.0.0 (`pubspec.yaml` `dependency_overrides`)

`sqlite3` ≥3.0.0 fetches a prebuilt native library from a GitHub release
via a build hook at `flutter test`/`flutter build` time. In this
development sandbox, that download is blocked (GitHub content access is
scoped to explicitly-added repos), which broke `flutter test` outright
even though no Drift/sqlite3 code has been written yet — the dependency
was only present because Module 0's setup command list includes
`sqlite3_flutter_libs`. Pinned `sqlite3: 2.9.4` (last pre-hook release) to
unblock local testing. **Revisit this override once the offline-queue
Drift database (docs/03-architecture.md, "Local storage") is actually
implemented** — confirm the pin still supports whatever Drift version is
in use at that point, or find an environment where the GitHub download
succeeds and drop the override.
