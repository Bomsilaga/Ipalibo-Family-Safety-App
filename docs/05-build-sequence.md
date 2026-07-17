# The Ipalibos — Build Sequence

Every module in `01-product-spec.md` is in scope and treated as equal priority per the family's decision. This document is **technical dependency order only** — later modules genuinely cannot be built before earlier ones (e.g. Chat needs Auth's user/family model to exist), not a statement that they matter less.

## 0. Repo & environment setup

```bash
flutter create --org com.theipalibos --platforms ios,android,web ipalibos
cd ipalibos
flutter pub add flutter_riverpod go_router supabase_flutter drift sqlite3_flutter_libs \
  firebase_messaging flutter_local_notifications google_maps_flutter geolocator \
  flutter_secure_storage image_picker record

supabase init
supabase link --project-ref <project-ref>
supabase migration new init_core_tables   # then paste 02-data-model.md's Core section
```

Set up `dev`/`staging`/`prod` Supabase projects and matching Flutter flavours before writing feature code (see `03-architecture.md` §6).

## 1. Foundation (build first — everything else depends on this)

- Design system package (`04-design-system.md` → `core/theme/`)
- Supabase project + `families`, `users`, `devices`, `trusted_devices` tables + RLS
- Auth flows: email/phone/Apple/Google sign-in, family creation, invite flow, child account creation by a parent, PIN for shared devices, biometric gate
- `hasPermission(user, action)` helper wired to the permission matrix in `01-product-spec.md` §2
- go_router skeleton + bottom nav shell (Home/Calendar/Tasks/Chat/Family/More)

**Definition of done:** a parent can create a family, add a child account, and both can log in on separate devices and land on an empty Home screen scoped to their family only (verify RLS by trying to query another family's data and confirming it's rejected).

## 2. Calendar

- `events`, `event_participants`, `event_attachments` tables + RLS
- CRUD, recurring events, conflict detection, Day/Week/Month/Timeline views, person filter chips
- Reminder scheduling hook (writes into `notifications`, actual delivery is module 4)

**Definition of done:** matches the calendar mockup — month grid, colour-coded chips per person, "Everyone" filter, quick-add flow.

## 3. Tasks / Chores / Homework / Reading

- `tasks`, `task_assignees`, `task_completions` tables + RLS
- Task builder (parent), status lifecycle, completion flow with evidence photo/note, morning/evening routine builder, templates, bulk assignment
- Dashboards (daily/weekly/monthly)

**Definition of done:** matches the Task Detail / Task Completed mockups; a chore created by a parent shows correctly on the assigned child's Home and Tasks tab, and tapping "I've Completed This" updates status and timestamp everywhere it's shown.

## 4. Notifications & Automation Engine

- `notifications`, `automation_rules` tables
- Edge Function `schedule-notifications`: cron/scheduled function that scans upcoming `events.start_at` and `tasks.due_time`, writes `notifications` rows, and calls FCM/APNs
- Reminder escalation levels 1–4 (level 5, device restriction, is module 6)
- Quiet hours, notification inbox, retry/offline queueing

**Definition of done:** this is the feature Boma asked for first — a chore set for a specific time actually arrives as a push notification on the assigned child's device at that time, and tapping it opens the task with the complete button ready.

## 5. Family Chat

- `chats`, `chat_members`, `messages`, `message_reactions`, `message_receipts` tables
- Family group auto-created on family creation; 1:1 chats; text/image/voice/document messages; reactions/replies; read receipts/typing indicators via Supabase Realtime
- Application-layer encryption for `messages.body`
- System messages from task completions / new appointments (integration hook, not a hard dependency — can land after basic chat works)

**Definition of done:** matches the Chat mockup; messages sync in real time across two devices in the same family.

## 6. Parental Controls & Device Unlock

- `device_restrictions`, `unlock_requests`, `audit_log` tables
- Reminder escalation level 5 hookup (from module 4)
- iOS: Family Controls / Screen Time integration — **blocked on the Apple entitlement request being approved; flag this dependency to the human early, it is not a code task**
- Android: app-restriction implementation per the level the family actually wants (confirm scope — see `03-architecture.md` §4)
- Unlock request lifecycle end-to-end, unlock code generation/validation as an Edge Function, audit logging

**Definition of done:** matches the Unlock Request mockup; a missed task past its grace period notifies the parent, the child can request unlock, and a generated code is single-use and expires correctly.

## 7. GPS Safety

- `locations`, `safe_zones`, `safe_zone_events` tables
- Background location capture (battery-conscious APIs per platform), Family Map, safe zone CRUD + arrival/departure alerts, travel history/route playback, school mode

**Definition of done:** matches the Live Location mockup; a safe zone entry/exit produces a real push alert to parents within a reasonable delay.

## 8. Emergency SOS

- `sos_events` table
- One-tap SOS reachable even from a restricted device state, fans out to all parents via push + optional SMS

**Definition of done:** SOS notification lands on all parent devices within seconds, including when the device is in a screen-time-restricted state.

## 9. Rewards

- `rewards`, `reward_ledger`, `redemptions` tables
- Reward builder, task-completion → points hook, reward store, redemption approval, streaks/leaderboard

**Definition of done:** completing an evidence-gated task awards points only after parent approval; redemption debits correctly and shows in the ledger.

## 10. Reports & Dashboards

- Aggregation queries/views over tasks, events, rewards, reading — Parent Dashboard and Child Dashboard matching the mockups; exportable weekly/monthly report

## 11. AI Assistant

- Daily briefing, conflict/free-time suggestions, natural-language quick-add (always drafts, never auto-saves), scoped strictly to the calling user's own permissions
- Everything beyond this (§18 Future Roadmap in the product spec) stays out of the codebase until explicitly requested

## 12. Settings

- Family settings (parent-only) and personal settings screens tying together every configurable option introduced in modules 1–11

---

## Cross-cutting, do continuously (not a phase)

- RLS policy + at least one widget test per new table/feature, as stated in `CLAUDE.md`
- Update `06-deviations.md` (create on first use) whenever a platform constraint forces a deviation from the spec, especially in modules 6 and 7
- Keep `reference/family-board.html` for interaction reference only — it has no bearing on the Flutter architecture
