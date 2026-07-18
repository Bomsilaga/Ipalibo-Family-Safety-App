# The Ipalibos — Product & Functional Specification

Consolidated from `The_Ipalibos_Master_Specification_v1.docx` and `The_Ipalibos_Full_Logic_Specification.md`, deduplicated, and reconciled with the UI mockups. This is the source of truth for **what** to build; see `03-architecture.md` for **how**.

## 1. Vision

A secure, cross-platform family management app — iOS, Android, tablet, web, cloud-synchronised in real time — combining shared scheduling, chores/routines, messaging, GPS safety, parental controls, rewards, homework/reading, and emergency features in one place.

**Tagline:** *Your Family. Organised. Safe. Connected.*

## 2. Roles & Permissions

Two account types for v1. A future `admin` role is reserved but out of scope.

**Parent** — full administrator within the family: invite/remove members, create child accounts, promote/demote parents, create and edit anyone's calendar events, create and manage chores/routines, view reports, manage GPS and safe zones, approve unlock requests, configure parental controls and screen time, view all chats, manage rewards, configure automation.

**Child** — view the family calendar; receive and complete tasks; chat; request unlock; send emergency SOS. Cannot: change their own account type, disable GPS or monitoring, delete audit history, remove assigned chores, edit family security settings, become a parent. Only a Parent can designate an account as Child.

### Permission matrix

| Action | Parent | Child |
|---|---|---|
| Create family | ✅ | ❌ |
| Invite member | ✅ | ❌ |
| Promote parent | ✅ | ❌ |
| Create child account | ✅ | ❌ |
| Delete family | ✅ | ❌ |
| Create/edit anyone's calendar event | ✅ | own only |
| Disable GPS sharing | ✅ | ❌ |
| Create tasks/chores | ✅ | ❌ |
| Complete own tasks | optional | ✅ |
| View reports | ✅ | ❌ |
| Configure AI / automation | ✅ | ❌ |
| Manage screen time / restrictions | ✅ | ❌ |
| Generate/approve unlock code | ✅ | request only |
| Manage rewards | ✅ | earn/redeem only |
| Emergency SOS | ✅ | ✅ |

Implement this as one `hasPermission(user, action)` check, not scattered `if role == 'parent'` conditionals.

## 3. Core Modules

1. Authentication & Family Setup
2. Shared Calendar
3. Chore & Routine Engine (Task Engine)
4. Notifications & Automation Engine
5. Family Chat
6. GPS Safety
7. Parental Controls & Device Unlock Workflow
8. Rewards
9. Homework & Reading
10. Reports & Dashboards
11. Emergency SOS
12. AI Assistant
13. Settings
14. Design System (see `04-design-system.md`)

---

## 4. Authentication & Family Setup

- Sign-in methods: email/password, phone, Apple Sign-In, Google Sign-In, biometric (Face ID / fingerprint) as a second factor on top of a session, PIN for children on shared devices, optional two-factor authentication for parents.
- **Registration flow:** create account → create family (name, avatar) or accept an invite → set role.
- **Family invitation:** parent invites adults by email/phone/link; invitee joins as Parent (co-parent) after acceptance.
- **Child creation:** only a Parent can create a child account — children do not self-register. Parent sets name, avatar, colour, birth year (for age-appropriate defaults), and optionally a PIN.
- **Child device registration:** each device registers device ID, OS, app version, push token, security posture where available, last sync time; parents can rename registered devices.
- **Sessions:** JWT access + refresh token; configurable session expiry (shorter for shared/child devices); trusted-device list per user; device verification on first login from a new device.
- **Password policy:** minimum length + complexity, breach-list check where available, recovery via email/phone with rate-limited codes; recovery codes for MFA.
- **Parent promotion / demotion:** existing Parent can promote another adult member to Parent or demote a co-parent, but a family must always retain at least one Parent.
- **Account lockout & suspicious activity:** exponential backoff after repeated failed logins; alert the family's parents on suspicious sign-in attempts.

## 5. Shared Calendar

**Event object fields:** id, family_id, owner_id, title, description, category, colour, icon, location (+ lat/lng), start, end, all_day, reminder(s), repeat rule, status, visibility, attachments, created_at, updated_at.

- **Views:** Day, Week, Month, Family Timeline (all members' events on one scroll), filterable by person via the "Everyone / [Name]" selector shown in the mockups.
- **Creating an appointment:** person picker (multi-select for shared events), title, date, start/end time, location, notes, reminder offset(s), repeat rule (none/daily/weekly/custom), attachments.
- Parents can edit anyone's events; children can edit only their own unless a parent restricts that.
- **Recurring events** with standard rules (daily/weekly/monthly/custom RRULE-style); **conflict detection** warns when a new event overlaps an existing one for the same person; **travel-time buffer** optional per event.
- **Colour coding** per family member (matches their avatar colour across the whole app — calendar, chat, GPS, dashboards).
- **Reminders:** configurable offsets (e.g. 30 min / 1 hr / 1 day before); delivered through the Notification Engine (§6).
- Quick-add from the "+" button; drag-and-drop to reschedule (web/tablet); event search; ICS export/print; family availability / "find free time" view.
- Offline: events created offline queue and sync when back online.

## 6. Chore & Routine Engine (Tasks)

**Task object fields:** id, family_id, owner/assignee(s), created_by, title, description (rich text + optional image/video/voice instructions), category, priority (Low/Normal/High/Critical/Emergency), difficulty, estimated_duration, start_date, due_date, due_time, grace_period, repeat_rule, requires_approval, requires_evidence, reward_id, penalty_id, status, created_at, updated_at.

- **Status lifecycle:** Upcoming → Due → Completed → (Late | Missed) → Approved. "Approved" only applies when `requires_approval` is true (a Parent confirms the completion).
- **Completion:** single tap "I've Completed This" button; optional photo/video evidence; optional note; timestamp recorded automatically.
- **Task builder (Parent):** title, instructions (rich text, attach image/video, record a voice note), category (Chore/Reading/Homework/Other), assignee(s), due time, grace period, repeat rule, whether it needs photo evidence and/or parent approval, linked reward/penalty.
- **Templates & routines:** Morning Routine and Evening Routine builders (ordered checklist of recurring tasks); reusable task templates; multi-step tasks / checklists within one task.
- **Bulk assignment:** apply one task to multiple children at once.
- **Dashboards:** Daily / Weekly / Monthly view per child and family-wide.
- Cross-links: Reading and Homework are specialised task categories (§9) that reuse this engine; tasks can attach to a calendar event; task completion can trigger a chat announcement and a reward.

## 7. Notifications & Automation Engine

This is the engine behind "send the instruction automatically at the right time and let them tap to mark it done," which is the feature Boma asked for first.

- **Categories:** appointments, chores, homework, reading, unlock requests, GPS alerts, chat, announcements, emergency alerts.
- **Scheduling engine:** every task/event with a due time gets a scheduled local + push notification; timezone-aware; respects each family's configured quiet hours.
- **Reminder escalation** (chores specifically):
  1. Gentle push at due time
  2. Push + sound + badge if not opened
  3. Persistent/sticky notification if still not completed
  4. Parent notified that the child hasn't completed it
  5. Platform-supported restriction workflow kicks in if configured (§8) — this step is optional per family and per task
- **Retry logic:** failed push delivery retries with backoff; falls back to in-app notification inbox.
- **Offline behaviour:** notifications queue locally and reconcile on reconnect so nothing silently disappears.
- **Notification inbox:** persistent in-app list of everything sent, independent of whether the OS notification was dismissed.
- **Quiet hours & bedtime mode:** parent-configurable per child; non-emergency notifications are suppressed and queued until quiet hours end.
- **Templates:** each notification type has a template (title/body/action) parents can lightly customise (e.g. "It's {time} — time for {task}, {name}!").
- **Automation rules:** simple "when X then Y" rules parents can define (e.g. "if a chore is missed twice in a week, notify both parents").

## 8. Parental Controls & Device Unlock Workflow

**This module is the most platform-constrained in the whole spec — read the platform notes before implementing anything here.**

- **Reminder escalation** feeds into this from §6 Task Escalation: Task Assigned → Reminder Sent → (Completed? → reward) or (Not completed → grace period → final reminder → parent notified → platform-supported restriction → unlock request if needed).
- **Device restriction — Android:** where permitted by Android device-management / parental-control capabilities: restrict access to selected apps, show a parental-approval screen, limit distracting apps, always keep emergency functions (SOS, calling) available.
- **Device restriction — iOS:** must use Apple's approved **Family Controls / Screen Time API**. The app must never attempt to bypass OS restrictions or lock the entire device — Apple will reject anything that tries. Possible actions: restrict managed apps, show task reminders, request approval through the supported API only.
- **Unlock request lifecycle:** Child taps "Request Unlock" → selects a reason → request sent → Parent gets a push notification → Parent reviews → Approve / Temporary approval / Reject → on approval, generate a one-time code (or transmit platform-supported approval) → child enters code or approval applies automatically → restriction lifts → event written to the audit log.
- **Unlock code rules:** cryptographically random, single-use, expires after 5 minutes, bound to the specific request and child, invalid immediately after use, capped retry attempts (default 5).
- **Screen time & homework mode / bedtime mode:** parent-defined windows where selected apps are limited or blocked, with an SOS/calling bypass always available.
- **Audit log:** every restriction, unlock request, and approval/denial is recorded and visible to parents; children cannot delete it.

**Compliance note:** device-level restriction is a *supported-API* integration, not a systems-level lock. Scope every "restrict/unlock" feature to what Apple's Family Controls / Screen Time API and Android's parental-control APIs actually expose — don't design a feature that requires circumventing OS sandboxing, or it will fail App Store / Play Store review outright.

## 9. Family Chat

- **Chat types:** family group chat (auto-created per family), private 1:1 chats, task/announcement threads.
- **Message types:** text, image, video, voice note, document, emoji, reactions, replies (quote-reply), edits, deletions (tombstoned, not hard-deleted, for audit).
- **Delivery states:** sent → delivered → read, with read receipts and typing indicators.
- **Search:** full-text message search; pinned messages; starred/saved messages.
- **Integrations:** a completed task, a new appointment, or a reward can post an automatic system message/announcement into the family chat.
- **Encryption:** end-to-end encryption for message content; media stored encrypted at rest.
- **Moderation & spam protection:** parents can remove any message in the family chat; rate limiting to prevent spam floods.
- **Future (not v1):** voice calls, video calls.

## 10. GPS Safety

- **Family Map:** live location pins per family member (with consent/role rules — children cannot disable sharing), last-updated timestamp, battery %.
- **Safe zones (geofences):** parent-defined zones (home, school, grandparents') with arrival/departure push alerts.
- **Travel history & route playback:** stored location history with a scrubbable timeline (parent-visible only).
- **Alerts:** arrival, departure, low battery, GPS disabled/unavailable, "expected arrival" overdue.
- **School mode:** suppresses non-emergency notifications and restricts app usage during configured school hours; location still tracked for safety.
- **Background tracking:** must use each platform's battery-conscious background location APIs (significant-location-change / geofencing APIs), not naive polling.
- **Privacy:** only parents can view history/live location; only parents can disable a child's location sharing (a child cannot turn this off); all access logged to the audit trail.

## 11. Emergency SOS

- One tap from anywhere in the app (including from a restricted/locked state) sends: current GPS, timestamp, battery level, and a short message to **all** parents simultaneously via push + SMS fallback if configured.
- SOS is exempt from quiet hours, screen-time restriction, and device-lock states.

## 12. Rewards

- **Types:** points, stars, badges, levels, streaks.
- **Earning:** completing a task (linked `reward_id`), hitting a streak, parent-defined bonus awards.
- **Reward builder (Parent):** define custom rewards (screen time, treat, outing, cash) and their point cost; define penalties for missed/late tasks if desired.
- **Reward store:** children redeem points against parent-defined rewards; redemption requires parent approval.
- **Streak engine, family challenges, leaderboard:** weekly/monthly challenges and a family leaderboard for motivation.
- **Ledger:** immutable log of every point earned/spent, visible to the child it belongs to and to parents.
- **Anti-cheat:** completion evidence (photo/note) and optional parent approval gate points earned from tasks that require it.

## 13. Homework & Reading

Both are specialised Task categories (§6) with extra fields:

- **Homework:** subject, due date, attachments, status — otherwise uses the standard task lifecycle.
- **Reading:** book title, target pages or minutes, optional comprehension questions, reading streak counter, weekly reading report for parents.

## 14. Reports & Dashboards

- **Parent dashboard:** today's tasks completed/missed, unlock requests pending, live locations preview, upcoming calendar, rewards summary, reading progress, homework status, family announcements, recent activity feed.
- **Child dashboard:** today's chores, homework, reading, next appointment, rewards progress, chat shortcut, SOS button.
- **Reports:** per-child weekly/monthly completion rate, streak history, reading minutes, reward earnings — exportable (PDF/CSV) for parents.

## 15. Settings

Family settings (Parent-only): manage members and roles, notification preferences per category, quiet hours/bedtime mode, GPS and safe-zone configuration, screen-time rules, reward economy configuration, data export, account deletion, security (MFA, trusted devices, audit log viewer).

Personal settings (all users): profile, avatar/colour, notification preferences within what the family allows, theme (light/dark), language.

## 16. AI Assistant (v1 scope: assistive, not autonomous)

- **Daily briefing:** a short summary per person each morning (today's appointments, tasks, reminders).
- **Smart scheduling suggestions:** flags calendar conflicts, suggests free-time slots, suggests reasonable due times for new tasks.
- **Reading/homework coaching prompts:** gentle nudges, not grading.
- **Natural-language quick-add:** "Alex has swimming Tuesday 4pm" → parsed into a draft event for parent confirmation (always confirm before saving — never auto-create on the child's behalf without parent visibility).
- **Boundaries:** the AI assistant never has permissions beyond the user invoking it (a child's AI queries can't see parent-only data or trigger parent-only actions); no data leaves the family's own account scope; families can disable the AI assistant entirely in Settings.
- Everything else in the original "AI Roles / Smart Shopping / Meal Planning / Voice Assistant" list is **Future Roadmap**, not v1 — see `05-build-sequence.md`.

---

## 17. Security & Compliance Notes (tweaked in from the original spec)

- Encrypted transport (TLS) everywhere; encrypted storage for chat media and location history; MFA and biometric auth support; role-based access control enforced server-side via RLS, never trusted from the client alone.
- **Audit log** covers: role changes, security-setting changes, GPS sharing toggles, unlock requests/approvals, message deletions by a parent, data export/deletion requests. Children cannot delete audit history.
- **Child privacy:** treat all child accounts as requiring parental consent and data minimisation by default — collect only what a feature needs, make data exportable and deletable on request, and don't share child location/chat data outside the family account under any circumstance. If this app is ever published to app stores, Apple's and Google's *Kids/Families* policies and applicable regional child-privacy law (e.g. COPPA in the US) apply to onboarding and data-handling flows — that review should happen before a store submission, not after.
- **Store review risk areas to plan for early:** background location justification text, Family Controls/Screen Time entitlement request (iOS), any SMS/emergency-contact feature needing carrier or platform approval, end-to-end encrypted chat needing export-compliance disclosure.

## 18. Future Roadmap (explicitly out of v1 code, kept for context)

AI meal planning, grocery scanner, budget tracker, medical records, school portal integration, smart home integration, wearable support, full voice assistant, shared photo memories, voice/video calling in chat.
