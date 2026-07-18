# The Ipalibos — Architecture

## 1. Stack decision

| Layer | Choice | Why |
|---|---|---|
| Client | **Flutter** (iOS, Android, Web from one codebase) | The master spec's own "Recommended Architecture" names Flutter first; a single codebase is the only realistic way one build produces both native apps plus web without duplicating every module (calendar, chat, GPS, unlock workflow) twice. React Native is the fallback if a specific package (e.g. a Screen Time binding) turns out Flutter-only-incomplete — decide per-module, not up front. |
| State management | Riverpod | Testable, compile-safe DI, works well with code-gen for repositories |
| Routing | go_router | Deep-linking (push notification → specific screen) is required for the reminder/unlock flows |
| Backend | **Supabase** (Postgres + Auth + Realtime + Storage + Edge Functions) | Gives Postgres + RLS + realtime subscriptions + auth out of the box; Edge Functions host the notification-scheduling and unlock-code logic server-side where it must live |
| Push | Firebase Cloud Messaging (Android) + APNs (iOS), both triggered from a Supabase Edge Function | Keeps the "who gets notified when" logic in one server-side place instead of duplicated per-client |
| Maps | Google Maps SDK (Android), Apple Maps or Google Maps (iOS) | Match platform convention; abstract behind one `MapProvider` interface so the choice can differ per platform |
| Local storage | Drift (SQLite) for offline queueing of events/tasks/chat | Needed for the explicit offline-mode requirements in §5/§6/§9 of the product spec |

## 2. API standards

- REST v1 exposed through Supabase's auto-generated PostgREST API plus custom Edge Functions for anything that needs server-side logic (notification scheduling, unlock code generation/validation, SOS fanout).
- Base URL pattern: `https://<project>.supabase.co/rest/v1/` for data, `https://<project>.functions.supabase.co/<fn>` for Edge Functions.
- Auth: Supabase Auth issues JWTs (OAuth2-based) with refresh tokens; biometric unlock happens on-device and gates access to an already-valid session, it does not replace the session token.
- All payloads JSON, UTF-8, HTTPS only.
- Every custom Edge Function validates the caller's `family_id` and role server-side before touching data — never trust a client-supplied `family_id`.

## 3. Security

- TLS everywhere; Supabase Storage buckets for media (chat, task evidence, avatars) set to private with signed URLs, never public.
- Row Level Security on every table (see `02-data-model.md`) — this is the actual permission enforcement layer, the client-side `hasPermission()` check is UX only, never the security boundary.
- Chat message bodies encrypted at the application layer before they hit `messages.body` (e.g. libsodium sealed boxes per chat) so Supabase itself never sees plaintext family chat.
- MFA optional for parents at v1, recommended default-on; biometric gate for opening the app on shared/child devices.
- `audit_log` is insert-only for every role — no delete/update policy exists for it, including for parents.
- Unlock codes: generate server-side in the Edge Function with a CSPRNG, store only the hash, single-use, 5-minute expiry, max 5 attempts, bound to the specific `unlock_requests.id`.

## 4. Platform-specific constraints (read before starting §7/§10 of the product spec)

- **iOS device restriction:** implement exclusively through Apple's **Family Controls / Screen Time API** (`FamilyControls`, `ManagedSettings`, `DeviceActivity` frameworks). This requires an Apple entitlement request — a human needs to apply for this capability in the Apple Developer portal before the feature can be tested on-device, let alone shipped. Do not attempt MDM-style full-device lock.
- **Android device restriction:** use Android's parental-control-adjacent APIs (App restrictions via `UsageStatsManager`/Device Policy Controller where the device is enrolled, or a simpler "block app opens via our own launcher overlay" approach if the family doesn't want a full MDM enrollment). Confirm with the family which level of control they actually want before building the heavier option.
- **Background GPS:** iOS significant-location-change / region-monitoring APIs and Android's `FusedLocationProviderClient` with a foreground service — both are the battery-conscious path; naive polling will fail battery-usage review on both stores and drain child devices fast.
- **Push notification delivery to a locked/restricted device:** SOS and unlock-request notifications must be able to reach the device even while other notifications are suppressed by quiet hours or screen-time mode — build the suppression logic to explicitly whitelist `emergency` and `unlock_request` categories, not as an afterthought.
- **App Store / Play Store review:** location-tracking-of-a-minor apps and parental-control apps sit in a reviewed category on both stores with extra disclosure requirements (clear in-app disclosure to the child that they're being located/monitored, a published privacy policy, purpose strings for location permissions). Budget time for this before submission — it is not a code task, it's a compliance task a human on the family has to complete (privacy policy hosting, App Store Connect declarations, Play Console Data Safety form).

## 5. Repository / folder structure

```
ipalibos/
  lib/
    core/
      theme/              # design tokens from 04-design-system.md
      routing/             # go_router config, deep-link handling
      auth/                # session, permission helper
      network/             # supabase client, edge function wrappers
      notifications/       # local + push notification plumbing
    features/
      calendar/
        data/ domain/ presentation/
      tasks/                # chores, homework, reading share this feature
        data/ domain/ presentation/
      chat/
        data/ domain/ presentation/
      gps/
        data/ domain/ presentation/
      parental_controls/
        data/ domain/ presentation/
      rewards/
        data/ domain/ presentation/
      reports/
        data/ domain/ presentation/
      sos/
        data/ domain/ presentation/
      settings/
        data/ domain/ presentation/
      ai_assistant/
        data/ domain/ presentation/
    widgets/                # shared design-system components (see 04)
  supabase/
    migrations/             # one file per table/RLS policy, matches 02-data-model.md
    functions/
      schedule-notifications/
      unlock-code/
      sos-fanout/
      chat-fanout/
  test/
  reference/
    family-board.html       # early HTML prototype, interaction reference only
```

## 6. Environments

- `dev`, `staging`, `prod` Supabase projects, matched by Flutter build flavours (`--flavor dev|staging|prod`) with separate bundle IDs so all three can be installed side-by-side on a test device.
- Secrets (Supabase URL/anon key, Maps API keys, FCM/APNs keys) via `--dart-define` at build time, never committed.
