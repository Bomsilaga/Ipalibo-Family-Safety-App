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

## Modules 2–12 (full build pass)

### Chat: application-layer E2E encryption deferred

`03-architecture.md` §3 calls for message bodies encrypted client-side
(libsodium sealed boxes per chat) before hitting `messages.body`. That
needs a per-family key-distribution scheme tied to device provisioning
(key generation on device, escrow/recovery for parents, key rotation on
member removal) — a design that shouldn't be improvised mid-module.
Currently bodies travel over TLS and sit behind family-scoped RLS, but
Supabase can technically read them. The repository (`chat_repository.dart`)
carries a matching note. Design and implement the key scheme before any
production launch.

### GPS: foreground check-in only; background tracking blocked on entitlements

Battery-conscious background tracking (iOS significant-location-change /
region monitoring, Android FusedLocationProvider + foreground service)
requires capabilities, purpose strings, and store declarations a human
must configure (docs/03-architecture.md §4). Implemented instead: manual
"Check in" (geolocator, foreground permission), latest-location list,
safe-zone CRUD centred on the current position. Safe-zone entry/exit
detection (and its alerts) activates once background location lands.
The full-bleed map view also awaits Google Maps API keys per platform;
the UI is list-first until then.

### Device restriction: workflow only, no OS-level enforcement yet

The unlock request → approve → one-time code lifecycle is fully
implemented (tables, Edge Function `unlock-code` with generate/redeem/
reject, parent and child UI, audit logging). What is NOT implemented is
actual OS-level app restriction: iOS Family Controls requires an Apple
entitlement request that must be approved before the capability can even
be tested (docs/05-build-sequence.md Module 6 flags this as a human
task), and the Android restriction level needs a family decision
(launcher overlay vs full device-policy enrollment). The escalation
pipeline stops at level 4 (parent notified) until then — level 5 hooks in
once the entitlement exists.

### SOS: SMS fallback not configured

`sos-fanout` delivers push + in-app notifications to all parents. The
spec's "SMS fallback if configured" needs a Twilio (or similar) account
and sender registration — human setup; the function skips SMS silently
when TWILIO_* env vars are absent.

### Notifications: FCM delivery needs the Firebase service account

`schedule-notifications` writes every reminder/escalation row (so the
in-app inbox always works) and delivers via FCM HTTP v1 only when
FCM_SERVICE_ACCOUNT_JSON is set as a function secret. APNs delivery for
iOS goes through the same FCM project once the APNs key is uploaded to
Firebase — human setup in both consoles. Local scheduled notifications
(flutter_local_notifications) are wired in the dependency list but the
device-side scheduling hookup lands with the push wiring, so reminder
level 1 currently arrives via server push/inbox rather than an
offline-capable local alarm.

### Reports: client-side aggregation, no PDF/CSV export yet

Weekly per-child completion and points come from client-side queries. At
family scale this is fine; the exportable PDF/CSV report (product spec
§14) should be a Postgres view + Edge Function when added, not more
client aggregation.

### AI assistant: deterministic, fully local

The daily briefing and natural-language quick-add are deliberately
implemented as local, deterministic logic over the caller's own visible
data — no LLM call, so no family data leaves the account scope (the §16
boundary) and a child's queries can never see parent-only data because
they run under the child's own RLS session. If a hosted-LLM upgrade is
ever wanted, it must be proxied through an Edge Function that enforces
the same scoping and must be a family-level opt-in in Settings.

### Auth: phone sign-in and MFA not yet wired; PIN/biometric gate done

Email/password, Apple, and Google sign-in are implemented. The device
PIN gate (children on shared devices) and biometric unlock are now
implemented as a local app lock (`core/auth/app_lock_service.dart` +
`/lock` screen): salted-SHA-256 PIN in the platform keystore via
flutter_secure_storage, biometrics via local_auth, engaged at cold start,
with SOS reachable from the locked state. Note this is a *device-local*
lock per the spec's intent ("PIN for children on shared devices" gating
an already-valid session) — it is not the server-side `users.pin_hash`
flow, which remains available for a future cross-device child sign-in.
Still open: phone OTP (needs an SMS provider) and optional parent MFA
(Supabase Auth MFA config) — both need provider setup a human does.
