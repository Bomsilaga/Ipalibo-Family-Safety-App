# The Ipalibos — Design System

Taken from the master spec's design tokens and cross-checked against the supplied UI mockups (login/onboarding, home, calendar month view, chat, task detail/completion, unlock request, live location, parent dashboard).

## Brand

**Name:** The Ipalibos
**Personality:** premium, calm, trustworthy — a family command centre, not a toy.

## Colour tokens

| Token | Hex | Use |
|---|---|---|
| Emerald 900 | `#0D4B45` | Primary brand surface (dark headers, onboarding, nav) |
| Emerald 700 | `#146A60` | Secondary emerald surface |
| Emerald 500 | `#23907F` | Interactive accents on dark surfaces |
| Gold 500 | `#C8A44D` | Primary CTA buttons ("Get Started", "Generate Unlock Code"), highlights |
| Ivory | `#F8F7F2` | Light-mode background |
| White | `#FFFFFF` | Cards, sheets |
| Success | `#2E7D32` | Completed states |
| Warning | `#F9A825` | Due-soon / grace-period states |
| Danger | `#D32F2F` | Missed / locked / SOS |
| Information | `#1976D2` | Informational badges |
| Disabled | `#BDBDBD` | Disabled controls |
| Gray 50–900 | standard 10-step neutral ramp | text, borders, dividers |

Each family member is additionally assigned one colour from a rotating set for calendar/chat/GPS colour-coding (this is separate from the brand palette — see `avatar_color` in the data model).

## Typography

- **Primary (body/UI):** Inter
- **Secondary (display/headings):** Fraunces — elegant serif, used sparingly for hero moments (onboarding, dashboard greeting), not for dense UI text
- **Monospace (data/timestamps):** IBM Plex Mono

Scale (px): Display 56 · Headline 40 · Title 28 · Subtitle 22 · Body Large 18 · Body 16 · Small 14 · Caption 12.

## Spacing & shape

- 8-point grid: 4, 8, 16, 24, 32, 40, 48, 56, 64.
- Corner radius: Small 8 · Medium 16 · Large 24 · Pill 999.
- Elevation levels: 0 flat · 1 cards · 2 dialogs · 3 sheets · 4 floating buttons · 5 modals.

## Iconography

Outlined icons by default; filled variant for the active/selected state. Core set: Home, Calendar, Tasks, Chat, Family, Rewards, GPS, Reports, Settings, Notifications, SOS.

## Key components (from the mockups)

- **Onboarding/splash:** emerald-900 full-bleed background, gold laurel-crest logomark, ivory wordmark, gold primary CTA, ivory ghost secondary CTA.
- **Auth screens:** ivory background, emerald headline, pill-shaped input fields, gold primary button, social sign-in as outlined secondary buttons.
- **Home / "Good morning" screen:** greeting + date in Fraunces, 4 KPI mini-cards (Appointments / Tasks / Messages / Unlock Requests) as compact stat tiles, "Upcoming Appointments" list with coloured left-rail avatar + time in mono, "Today's Tasks" list with status pill + inline "Done" action.
- **Calendar (month view):** top filter row of family-member avatar chips (incl. an "Everyone" chip) matching each person's colour, day cells show 1–2 event chips colour-coded by owner, view toggle Day/Week/Month/List.
- **Task Detail:** category tag, red due-time line when close/overdue, assignee avatar, rich instructions block, attachment chip, repeat indicator, large primary "I've Completed This" button pinned to the bottom.
- **Task Completed:** trophy illustration, congratulatory Fraunces headline, timestamp, "Done" button — this is the payoff screen after a chore tap, keep it quick (auto-dismiss or one tap).
- **Chat:** emerald header bar, ivory bubble background, sender-coloured bubble accents, inline voice-note player, reaction counts under bubbles, bottom input bar with attach/voice/send.
- **Unlock Request (Parent view):** lock illustration, "X's device is locked", the missed task named plainly, single gold "Generate Unlock Code" primary action, recent unlock history list below with 6-digit codes.
- **Live Location:** full-bleed map, bottom sheet with avatar, "last updated", address, speed, battery — tab bar for Map / History / Places / Alerts.
- **Parent Dashboard (web/tablet):** left rail nav (Dashboard, Calendar, Tasks, Chat, Locations, Unlock Requests with a badge count, Reports, Rewards, Screen Time, Settings), top KPI row, then a grid of cards: Live Locations, Today's Schedule, Recent Activity, Reading Progress, Rewards, Announcements.

## Mobile navigation

Bottom tab bar (child + parent mobile): Home · Calendar · Tasks · Chat · Family · More. "More" surfaces GPS, Rewards, Reports, Settings, SOS on mobile to avoid an overcrowded tab bar; SOS also gets a persistent, faster entry point (long-press on tab bar or a dedicated corner button) since it must be reachable in one motion.

## States to design/build for every component

Default, hover (web), focus, disabled, loading, error, empty. Empty states are an invitation to act (e.g. "No appointments yet — tap + to add one"), not a dead end.

## Accessibility

WCAG AA contrast minimum; minimum touch target size on all interactive elements; dark mode preserves brand colours (don't drop to pure black); respect OS-level reduced-motion setting.

## Flutter mapping

Ship a `core/theme/` package exposing these tokens as `ThemeExtension`s (`AppColors`, `AppTypography`, `AppSpacing`) so every feature module pulls from one source instead of hardcoding hex values — this is what keeps 6+ feature teams visually consistent without a shared Figma library in v1.
