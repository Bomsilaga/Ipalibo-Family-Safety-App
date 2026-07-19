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

### RLS: SELECT policies on `families` and `users` must let a founder see their own not-yet-onboarded rows

`current_family_id()` is `STABLE` and reads `public.users`, so it can't see
a row that the *current* statement is still in the middle of inserting. The
founding parent's flow — `insert into families ... returning` immediately
followed by `insert into users ... returning` — hit this twice: PostgREST's
`RETURNING` (used by every `.select()` call) checks the row against the
table's SELECT policy, not just its INSERT `WITH CHECK`. Before the
founder's `users` row exists, `current_family_id()` returns null, so
`id = current_family_id()` fails on both tables even though the insert
itself was permitted. Fixed by adding `families.created_by` (defaults to
`auth.uid()`) and widening both SELECT policies to also match on
"this is my own row" (`created_by = auth.uid()` / `id = auth.uid()`) —
applied directly to the live project, documented in `02-data-model.md`.

### RLS: `events` ↔ `event_participants` circular policy reference

`events`' SELECT policy checked participation via a subquery on
`event_participants`; `event_participants`' policies checked back into
`events` via a subquery. Each subquery re-triggers the other table's RLS
(subqueries against a table go through that table's policies same as any
other query), so Postgres detected infinite recursion (`42P17`) the first
time a client tried to create an event. Fixed by adding three
`SECURITY DEFINER` helpers (`is_event_participant`, `event_owner_or_parent`,
`family_id_of_event` — same bypass-RLS-on-the-way-through pattern as
`current_family_id()`/`is_parent()`/`is_chat_member()`) and rewiring both
tables' policies to call them instead of querying each other directly.
Audited every other cross-table RLS policy in the schema for the same
mutual-reference shape (`chat_members`, `messages`, `redemptions`,
`task_assignees`, `task_completions`, `safe_zone_events`,
`event_attachments`) — all of them are one-directional (child table checks
its parent, parent never checks back), so this was isolated to `events`.

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

### GPS: reverse geocoding added; map tile now wired in (one shared key, restrict per platform before shipping)

Check-in and member tiles used to show raw lat/lng, which reads as broken
to a non-technical user. Added `GpsRepository.reverseGeocode` (OpenStreetMap
Nominatim, free, no API key) to turn coordinates into a place string
("14 Smith St, Fitzroy"). Separately, a Google Maps API key was provided
and wired into all three platforms: `web/index.html` (Maps JS API script
tag), `android/app/src/main/AndroidManifest.xml`
(`com.google.android.geo.API_KEY` meta-data), and
`ios/Runner/AppDelegate.swift` (`GMSServices.provideAPIKey`) — the Family
and Places tabs in `gps_screen.dart` now render an actual `GoogleMap` with
member markers / safe-zone circles above the list, not just coordinates.

**Same key value on all three platforms is a placeholder, not the end
state.** Google Cloud Console restricts a Maps key by exactly one
mechanism — HTTP referrer (web) *or* Android package+SHA-1 *or* iOS bundle
ID — so one key cannot be properly restricted for all three at once. Before
shipping to app stores: mint separate keys per platform in Cloud Console,
restrict each to its platform, and swap the Android/iOS values. The web key
should be restricted to `ipalibos.vercel.app` and
`ipalibo-family-safety-app.vercel.app` — a human task in Cloud Console this
repo can't do on its own.

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

### Edge Functions: missing CORS headers blocked every browser call

None of the six Edge Functions handled CORS at all. Supabase Edge Functions
add no CORS headers by default, and the four called directly from the
Flutter web client (`create-child-account`, `accept-invite`, `unlock-code`,
`sos-fanout`) only checked `req.method !== 'POST'` and returned 405 for
anything else — including the browser's CORS preflight `OPTIONS` request,
which every cross-origin POST with an `Authorization`/`Content-Type` header
triggers. The preflight failed before the real POST was ever sent, so
"Add a child," invite acceptance, unlock code generation/redemption, and
SOS all silently failed from the web app with no way for the client to see
why (the browser blocks the response, not the server — nothing to catch).
`chat-fanout` and `schedule-notifications` are only invoked server-side
(DB trigger / cron) and were unaffected.

Fixed by adding an `OPTIONS` branch (returns 200 with
`Access-Control-Allow-*` headers) and CORS headers on every response,
success and error, in all four browser-invoked functions. Root-caused via
`get_logs(service: 'edge-function')`, which showed `OPTIONS | 405` for
`create-child-account`; verified the fix with a direct `curl -X OPTIONS`
against the live function and an end-to-end browser test (Playwright)
that successfully created a child account through the deployed UI.

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

### Auth: child PIN sign-in implemented (real session, not a UI-only switch)

"Chat from one user doesn't appear in the central chat" turned out not to
be a chat bug: neither child account had ever sent a message, because
there was no way for a child to sign in at all. Children have no
email/password by design (docs/01-product-spec.md §4 — they authenticate
via PIN/biometric against "an already-registered family device session"),
but that PIN flow was never built; `app_lock_service.dart` only gates
re-opening an *already signed-in* session, it doesn't switch identity.

Implemented properly rather than faked client-side: a child tapped in
`/switch-profile` doesn't just flip a local "active profile" flag while
the device stays authenticated as whoever signed in last — that would
make every RLS check (`sender_id = auth.uid()`, etc.) still see the
parent, not the child. Instead the new `child-sign-in` Edge Function
verifies the PIN server-side against `pin_hash`, then mints a one-time
Supabase magic-link token for the child's own auth identity via the Admin
API (`generateLink`); the client redeems it with
`supabase.auth.verifyOTP(type: magiclink, tokenHash: ...)`, which
installs a real session for the child. No password, no email sent to
anyone — magic-link is reused purely as Supabase's supported mechanism
for minting a session for a user that has none.

`AuthRepository.setChildPin` (parent-only, enforced by existing RLS)
hashes and stores the PIN; a "Set PIN" action was added next to each
child in `/switch-profile` since PIN entry wasn't previously exposed
anywhere post-creation.

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
