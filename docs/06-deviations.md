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

### Chat: voice/video calls via Daily.co (encrypted in transit, not E2E)

Added `public.calls` (family-scoped, Realtime-enabled so every device sees
a new call the instant it's created — that's the "incoming call" signal)
and two Edge Functions: `start-call` creates a Daily.co room server-side
(the Daily API key lives in Supabase Vault, read through the
service-role-only `public.get_secret()` RPC — never reaches the client)
and inserts the `calls` row; `end-call` tears the room down and marks it
ended. On web, `CallScreen` embeds the room directly as an iframe — Daily's
own room page is already a complete call UI (video, audio, mute, screen
share), so that's the entire client integration, no Daily SDK needed.
Native iOS/Android builds currently show a placeholder
(`call_view_stub.dart`): Daily's Flutter SDK talks to native platform
WebRTC bindings, not a web view, so mobile needs that SDK added as a
follow-up before calls work outside the web app.

Calls are encrypted in transit (standard WebRTC SRTP/DTLS, same guarantee
Daily gives every room) but not end-to-end — Daily's infrastructure can
technically access media the same way Supabase can technically read chat
message bodies today. True E2E for calls would need Daily's E2EE mode
(still routes through their SFU, adds client-side key exchange) and is a
separate scope decision from the E2E chat encryption above — not done here.

**Redone for real multi-party behaviour** after the first pass shipped
with three bugs: (1) every tap of the call button created a brand new
Daily room, so a second family member joining a "call in progress"
actually ended up alone in their own disconnected room — `startCall` now
looks for an existing `ringing`/`active` call on the chat and returns
that one instead of always minting a fresh room; (2) nothing ever moved
a call's status off `ringing`, so the "X is calling…" banner (and the
call screen itself) said "calling" forever even once someone had
answered — `CallsRepository.markActive` flips it to `active` the moment
a *second* device (not the creator's own screen) opens the call; (3) an
open `CallScreen` had no way to learn a call had ended elsewhere, so
hanging up on one device left every other device sitting on a dead Daily
room — it now watches the call row live (`watchCall`) and closes itself
the instant the row flips to `ended`. Declining an incoming call is now
purely local (`dismissedCallsProvider`, a per-device set) rather than
calling `endCall` — a decline used to end the call for the caller and
everyone else too, backwards from how a group call should behave; only
explicitly hanging up (the X button, or the caller ending it) tears the
whole call down, matching the "any family member can end a call"
model the `end-call` function already implements server-side.

### Chat: image attachments via a private Supabase Storage bucket

Added the `chat-media` Storage bucket (private, not `public: true`) with
RLS mirroring the family-scoping pattern used everywhere else: objects
are keyed `{family_id}/{chat_id}/{timestamp}.{ext}`, and
`storage.foldername(name)[1] = current_family_id()` gates read/write, so
one family's photos are never reachable by another family's session —
same child-privacy/data-minimisation bar as the rest of the schema.

Because the bucket is private, `messages.media_url` stores the *storage
path*, not a public URL — every read (each image bubble) calls
`createSignedUrl` for a fresh 1-hour-expiry link via
`ChatRepository.signedUrlForPath`, rather than persisting a URL that
would eventually 403. Upload goes through `image_picker` (already a
dependency; works on web via its web plugin) → `uploadBinary` → insert a
`messages` row with `type: 'image'`. Tapping a thumbnail opens a
full-screen `InteractiveViewer`. Video/voice/document attachment types
that the `messages.type` check-constraint already allows are not built —
only images, since that's what was actually requested.

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

### Auth: "Add a child" redone as an invite code, not a parent-created account

Superseded per explicit request. The original "Add a child" flow (parent
fills in name/birth year/PIN, `create-child-account` mints an account
with a synthetic `child.<uuid>@device.theipalibos.internal` email) is
still deployed but no longer reachable from the UI — a child's own email
is now the identity, matching how a co-parent joins.

"Add a child" in the Family tab now calls the exact same
`FamilyInviteRepository.createInvite` a co-parent invite uses, just with
`role: 'child'` — the backend already supported this generically
(`accept-invite` assigns whatever role the invite row carries, it never
hardcoded 'parent'). The child creates their own account with their own
email on the sign-in screen, then redeems the code via
`/family-setup`'s existing "I have an invite code" branch — no new
screen needed, one flow now serves both roles. The device-PIN
(`child-sign-in`, `setChildPin`, `/switch-profile`) flow described above
still exists for shared-device switching, but is now something a parent
opts into per child from the Family tab's member options sheet, not
how a child account is created.

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

### Auth: one-tap invites by email; welcome screen matches the brand mockup

Adding a family member (child or co-parent) is now a single step for the
parent — type an email, tap Send invite — and a single tap for the
invitee. The new `invite-member` Edge Function mints the code, stores
only `sha256(code)` in `family_invites` (unchanged contract, so
`accept-invite` validates it exactly as before), and calls the Admin
API's `inviteUserByEmail` with `redirectTo` pointing at
`/#/join?code=…`. That link both confirms the address and signs the
invitee in, so they land already authenticated on `JoinInviteScreen`,
which stores the code and hands off to `/family-setup` — where it is
pre-filled and their display name is pre-guessed from their email. In
the happy path nobody reads out or types a code.

Two things this deliberately does *not* assume:

- **Email delivery is best-effort.** Supabase's built-in SMTP is
  rate-limited to a handful of sends per hour and this project has no
  custom SMTP configured, so `invite-member` returns `emailed: true|false`
  plus the link and code regardless, and the UI always offers Copy
  link / Share (via `share_plus`). A parent standing next to their kid
  can just share it directly. Configuring custom SMTP in Supabase Auth
  settings is what makes the emailed path reliable.
- **The pending code has to survive a page reload.** If the invitee
  signs up with a password instead of following the emailed link, they
  leave for their inbox and return on a fresh page load, so the code is
  persisted (`PendingInviteStore`, flutter_secure_storage) rather than
  held in memory, and cleared as soon as it's redeemed so a stale code
  can't attach an unrelated later sign-up on the same device to the
  family.

Also restyled the signed-out entry to the brand mockup: a new `/welcome`
screen (emerald field, gold crest/wordmark, "Get Started" and "I already
have an account") is now where signed-out users land instead of the bare
form, and `/sign-in` gained the crest header, "Welcome Back" / "Sign in
to continue" copy, and an "or continue with" divider. The crest is drawn
in Dart (`brand_crest.dart`) rather than shipped as a PNG so it takes the
theme's gold token and stays crisp at any size.

Still needing action outside this repo: **Google and Apple OAuth are both
disabled** on the Supabase project (`/auth/v1/settings` reports
`google: false, apple: false`), which is why the mockup's "Continue with
Google/Apple" buttons don't render — the sign-in screen deliberately
hides a provider until the project reports it enabled, because on web a
disabled provider redirects to Supabase's raw JSON error page before any
Dart runs. Enabling Google in Supabase Auth → Providers (needs a Google
Cloud OAuth client) is what turns on true one-tap sign-in. The invite
`redirectTo` URL must also be present in Auth → URL Configuration →
Redirect URLs, or Supabase silently falls back to the Site URL.

### Family: removing a member detaches rather than deletes

`01-product-spec.md` §15 lists "manage members" as parent-only. Added the
`remove-member` Edge Function (parent-only, verified server-side) behind
a "Remove from family" action in each member's options sheet.

It sets `users.family_id = null` instead of deleting the row.
`public.users.id` is referenced by `messages.sender_id`,
`task_assignees`, `task_completions`, `reward_ledger` and others, so a
hard delete either trips a foreign key or takes family history with it —
a chore someone completed last month should still show who completed it.
Nulling `family_id` makes `current_family_id()` return null for them, so
every family-scoped RLS policy stops matching and their access ends
immediately, which is the actual requirement.

Three things *are* deleted rather than detached: `chat_members` (so they
stop receiving family chat), `devices` (push tokens live there — leaving
them would keep delivering family notifications to someone no longer in
the family), and `locations` (GPS history is the most sensitive residue,
and holding it after removal fails the child-privacy bar in CLAUDE.md:
data minimisation, deletable data). No "last parent" guard is needed —
the caller is a parent, can't target themselves, and stays.

### Auth: Google/Apple buttons always render, enablement checked on tap

Previously the social buttons were hidden unless `/auth/v1/settings`
reported the provider enabled, which meant the brand mockup's "Continue
with Google" simply never appeared (the project has `google: false`).
They now always render, matching the mockup, and `_oAuthSignIn` checks
enablement *before* calling `signInWithOAuth` — on web that call is a
top-level browser redirect that fires before any Dart runs, so a
disabled provider would otherwise dump the user on Supabase's raw JSON
error page with no exception to catch. When it's off, the screen says
which provider to switch on in Supabase → Authentication → Providers
instead. The Google "G" is painted in Dart (`_GoogleGlyph`) in its four
brand colours; Material's `Icons.g_mobiledata` is a single-colour glyph
that reads as a generic letter rather than as Google.

## Android

### Release manifest was missing `INTERNET` (and every runtime permission)

Flutter's project template declares `android.permission.INTERNET` only in
`android/app/src/debug/AndroidManifest.xml` and the `profile/` one, on the
reasoning that release apps should opt in deliberately. The practical
effect is that the **release APK shipped with no network access at all** —
every Supabase call fails, so the app opens to a permanently loading
screen and nothing else. Declared it in `src/main/` so it reaches release
builds.

The same manifest was also missing every runtime permission the app's own
features need, none of which surface until you run on a device:
`ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` (Live Location check-ins
and SOS — COARSE is declared alongside FINE because Android 12+ lets a
user grant approximate-only, and the app must still work then), `CAMERA` +
`RECORD_AUDIO` + `MODIFY_AUDIO_SETTINGS` (calls and photo attachments),
and `POST_NOTIFICATIONS` (reminders on Android 13+). Camera is declared
`uses-feature ... required="false"` so a device without one can still
install and use everything else.

### Calls now work on Android — WebView, still no Daily SDK

The previous note here said native calling needed Daily's Flutter SDK and
`call_view_stub.dart` showed a "use the web app" placeholder. That turned
out to be unnecessary: Daily's room page is a complete prebuilt call UI,
and loading it in a `webview_flutter` WebView gives the same experience
the web build gets from an iframe. The stub is now a real implementation.

The detail that makes or breaks it is `setOnPlatformPermissionRequest` —
an Android WebView denies `getUserMedia` by default, so without granting
it the room loads and looks fine but the camera and microphone stay dead,
which is indistinguishable from a broken call. `setMediaPlaybackRequires
UserGesture(false)` is also needed or the other participant's audio
doesn't start until the user taps the video.

### Android items still outstanding (need a device or console access)

- **Maps SDK for Android is a separate API from Maps JavaScript API.**
  Enabling the latter (which fixed the web map) does *not* enable the
  former, so the Live Location map will fail on Android until "Maps SDK
  for Android" is enabled on the same Google Cloud project. The key also
  needs an Android restriction (package `com.theipalibos.ipalibos` +
  signing SHA-1) or no restriction — an HTTP-referrer restriction, which
  is what a web key wants, rejects Android calls.
- **Push notifications don't work.** `firebase_messaging` is a dependency
  but is never initialised anywhere in `lib/`, and there is no
  `android/app/google-services.json`. Reminders currently rely on
  `flutter_local_notifications` (device-local scheduling) only; true push
  needs a Firebase project wired up.
- **Invite links open the browser, not the app.** The emailed link is
  `https://…/#/join?code=…`; opening the app instead needs an
  App Links intent-filter plus a hosted `.well-known/assetlinks.json`
  containing the release signing certificate's SHA-256. The `#` fragment
  also means go_router's native (non-hash) routing wouldn't see the path,
  so the link format needs revisiting at the same time. Not attempted
  because none of it can be verified without a device.
- **The APK is signed with the debug key.** `android/app/build.gradle.kts`
  still uses `signingConfigs.debug` for release. Fine for sideloading to
  try it out; a Play Store upload needs a real keystore.

### RLS: `enforce_users_guardrails` blocked its own Edge Functions

Live-testing `remove-member` returned "only a parent can change role or
family membership" on every call, from the *database trigger*, not from
the function's own checks. `enforce_users_guardrails` guards role and
family-membership changes by calling `public.is_parent()`, which reads
`auth.uid()`. Service-role connections carry no JWT, so `auth.uid()` is
null, `is_parent()` is false, and the trigger rejected the write —
`remove-member` sets `users.family_id = null`, which is exactly the
condition being guarded.

Fixed in `20260725000001_users_guardrail_allow_service_role.sql` by
exempting `auth.role() = 'service_role'` from the `is_parent()` check
only. The service role reaches that path solely through Edge Functions
that already verify server-side that the caller is an authenticated
parent acting inside their own family, so the property that matters — a
child cannot move themselves between families or promote themselves —
is preserved. The last-parent rules still apply to every caller.

Verified end-to-end against the live project afterwards: the target's
`family_id` goes null, their `users` row survives (so family history
still resolves), `chat_members`/`devices`/`locations` rows are gone, an
`audit_log` row is written, and both guards hold — removing yourself is
rejected, and so is removing someone in another family.
