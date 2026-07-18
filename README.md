# The Ipalibos

A secure, cross-platform family management app — shared calendar,
chores/routines, messaging, GPS safety, parental controls, rewards,
homework/reading, and emergency features in one place.

**Tagline:** *Your Family. Organised. Safe. Connected.*

Read `CLAUDE.md` and `docs/01-product-spec.md` through `docs/05-build-sequence.md`
before making changes — those docs are the source of truth for what to build
and how. `docs/06-deviations.md` tracks places the implementation had to
diverge from spec.

## Stack

Flutter (iOS, Android, web) · Riverpod · go_router · Supabase (Postgres,
Auth, Realtime, Storage, Edge Functions) · Drift (offline queueing) · FCM/APNs
push. See `docs/03-architecture.md` for the full rationale.

## Getting started

```bash
flutter pub get

# Point the app at a Supabase project (see supabase/migrations for schema):
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Apply the schema to your Supabase project:

```bash
supabase link --project-ref <project-ref>
supabase db push   # applies everything under supabase/migrations
supabase functions deploy create-child-account
```

## Testing

```bash
flutter analyze
flutter test
```

Note: `pubspec.yaml` pins `sqlite3` below 3.0.0 via `dependency_overrides` —
see `docs/06-deviations.md` for why, and revisit it once the offline-queue
Drift database is implemented.

## Project layout

```
lib/
  core/       # theme, routing, auth/permissions, network, notifications — shared by every feature
  features/   # one folder per module (data/domain/presentation), per docs/03-architecture.md §5
  widgets/    # shared design-system components
supabase/
  migrations/ # one file per table + its RLS policy
  functions/  # Edge Functions (service-role logic: child accounts, notifications, unlock codes, SOS fanout)
docs/         # product spec, data model, architecture, design system, build sequence, deviations
reference/    # early HTML prototype — interaction reference only, not the architecture
```
