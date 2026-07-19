# The Ipalibos — Data Model (Supabase / Postgres)

Every table below carries `family_id uuid references families(id)` and must have Row Level Security enabled with a policy of the shape "row's `family_id` = the caller's `family_id`" as a baseline, then tightened per-table for parent-only writes. Write the RLS policy in the same migration that creates the table.

## Core

```sql
families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  avatar_url text,
  timezone text not null default 'Australia/Melbourne',
  quiet_hours_start time,
  quiet_hours_end time,
  created_by uuid references auth.users(id) default auth.uid(), -- the founding parent; lets them see/select the row they just created via RETURNING before their own `users` row (and thus current_family_id()) exists
  created_at timestamptz not null default now()
)

users (
  id uuid primary key references auth.users(id),
  family_id uuid references families(id),
  role text not null check (role in ('parent','child')),
  display_name text not null,
  avatar_color text not null,      -- hex, drives calendar/chat/GPS colour coding
  avatar_url text,
  birth_year int,                  -- children only, drives age-appropriate defaults
  pin_hash text,                   -- children on shared devices, optional
  created_by uuid references users(id), -- parent who created this account, for child rows
  created_at timestamptz not null default now()
)

devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  family_id uuid references families(id),
  os text check (os in ('ios','android','web')),
  app_version text,
  push_token text,
  device_name text,
  last_sync_at timestamptz,
  created_at timestamptz not null default now()
)

trusted_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  device_fingerprint text not null,
  trusted_at timestamptz not null default now()
)

family_invites (
  -- Added during Module 1 (Foundation) to back the "Family invitation" flow
  -- in 01-product-spec.md §4: a parent invites by email/phone/link, the
  -- invitee joins as Parent (co-parent) after acceptance. A direct client
  -- INSERT into `users` for "join an existing family" is deliberately not
  -- permitted by RLS (see 03-architecture.md) — acceptance must go through
  -- a service-role Edge Function that validates the token first.
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  invited_by uuid references users(id),
  email text,
  phone text,
  role text not null default 'parent' check (role in ('parent','child')),
  token_hash text not null,          -- hash of the one-time invite token, never store plaintext
  status text not null default 'pending' check (status in ('pending','accepted','expired','revoked')),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_by uuid references users(id),
  accepted_at timestamptz,
  created_at timestamptz not null default now()
)
```

## Calendar

```sql
events (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  owner_id uuid references users(id),
  title text not null,
  description text,
  category text,
  color text,                       -- defaults to owner's avatar_color
  icon text,
  location text,
  latitude double precision,
  longitude double precision,
  start_at timestamptz not null,
  end_at timestamptz,
  all_day boolean not null default false,
  repeat_rule text,                 -- RRULE string, null = one-off
  reminder_offsets int[] default '{30}', -- minutes before, supports multiple
  status text not null default 'confirmed' check (status in ('confirmed','cancelled','tentative')),
  visibility text not null default 'family' check (visibility in ('family','private')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
)

event_participants (
  event_id uuid references events(id),
  user_id uuid references users(id),
  primary key (event_id, user_id)
)

event_attachments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id),
  file_url text not null,
  file_type text,
  created_at timestamptz not null default now()
)
```

## Tasks / Chores / Homework / Reading

```sql
tasks (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  created_by uuid references users(id),
  title text not null,
  description text,
  instructions_rich text,           -- rich text body
  voice_note_url text,
  image_url text,
  video_url text,
  category text not null check (category in ('chore','reading','homework','other')),
  priority text not null default 'normal' check (priority in ('low','normal','high','critical','emergency')),
  difficulty text,
  estimated_minutes int,
  start_date date,
  due_date date not null,
  due_time time not null,
  grace_period_minutes int not null default 90,
  repeat_rule text,                 -- null = one-off, else RRULE-style
  requires_approval boolean not null default false,
  requires_evidence boolean not null default false,
  reward_id uuid references rewards(id),
  penalty_points int,
  -- reading-specific
  book_title text,
  target_minutes int,
  target_pages int,
  -- homework-specific
  subject text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
)

task_assignees (
  task_id uuid references tasks(id),
  user_id uuid references users(id),
  primary key (task_id, user_id)
)

task_completions (
  id uuid primary key default gen_random_uuid(),
  task_id uuid references tasks(id),
  user_id uuid references users(id),
  scheduled_date date not null,     -- which occurrence, for repeating tasks
  status text not null default 'upcoming' check (status in ('upcoming','due','completed','late','missed','approved')),
  completed_at timestamptz,
  evidence_photo_url text,
  evidence_note text,
  approved_by uuid references users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now()
)
```

## Notifications & Automation

```sql
notifications (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  user_id uuid references users(id),
  category text not null check (category in
    ('appointment','chore','homework','reading','unlock_request','gps_alert','chat','announcement','emergency')),
  title text not null,
  body text not null,
  related_type text,                -- 'task' | 'event' | 'unlock_request' | ...
  related_id uuid,
  scheduled_for timestamptz not null,
  sent_at timestamptz,
  read_at timestamptz,
  escalation_level int not null default 1,
  created_at timestamptz not null default now()
)

automation_rules (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  created_by uuid references users(id),
  trigger text not null,            -- e.g. 'task_missed_twice_in_week'
  action text not null,             -- e.g. 'notify_parents'
  config jsonb not null default '{}',
  enabled boolean not null default true,
  created_at timestamptz not null default now()
)
```

## Parental Controls / Unlock

```sql
device_restrictions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  child_id uuid references users(id),
  restriction_type text not null,   -- 'app_limit' | 'screen_time' | 'bedtime' | 'homework_mode'
  config jsonb not null default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now()
)

unlock_requests (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  child_id uuid references users(id),
  reason text,
  status text not null default 'pending' check (status in ('pending','approved','temporary','rejected','expired')),
  reviewed_by uuid references users(id),
  reviewed_at timestamptz,
  code_hash text,                    -- hashed one-time code, never store plaintext
  code_expires_at timestamptz,
  code_used_at timestamptz,
  attempt_count int not null default 0,
  created_at timestamptz not null default now()
)

audit_log (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  actor_id uuid references users(id),
  action text not null,
  target_type text,
  target_id uuid,
  metadata jsonb default '{}',
  created_at timestamptz not null default now()
)
-- audit_log rows are insert-only; no update/delete policy for any role, including parent.
```

## Chat

```sql
chats (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  type text not null check (type in ('family_group','direct','announcement')),
  created_at timestamptz not null default now()
)

chat_members (
  chat_id uuid references chats(id),
  user_id uuid references users(id),
  primary key (chat_id, user_id)
)

messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid references chats(id),
  sender_id uuid references users(id),
  type text not null check (type in ('text','image','video','voice','document','system')),
  body text,                         -- encrypted at application layer before storage
  media_url text,
  reply_to_id uuid references messages(id),
  edited_at timestamptz,
  deleted_at timestamptz,            -- tombstone, never hard-delete
  created_at timestamptz not null default now()
)

message_reactions (
  message_id uuid references messages(id),
  user_id uuid references users(id),
  emoji text not null,
  primary key (message_id, user_id, emoji)
)

message_receipts (
  message_id uuid references messages(id),
  user_id uuid references users(id),
  delivered_at timestamptz,
  read_at timestamptz,
  primary key (message_id, user_id)
)
```

## GPS Safety

```sql
locations (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  user_id uuid references users(id),
  latitude double precision not null,
  longitude double precision not null,
  accuracy_m double precision,
  battery_pct int,
  recorded_at timestamptz not null default now()
)
-- write via a small edge function on a battery-conscious interval, not raw client inserts on every GPS tick.
-- consider a retention policy / downsampling job for locations older than N days.

safe_zones (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  radius_m int not null default 150,
  created_by uuid references users(id),
  created_at timestamptz not null default now()
)

safe_zone_events (
  id uuid primary key default gen_random_uuid(),
  safe_zone_id uuid references safe_zones(id),
  user_id uuid references users(id),
  event_type text not null check (event_type in ('arrival','departure')),
  occurred_at timestamptz not null default now()
)

sos_events (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  user_id uuid references users(id),
  latitude double precision,
  longitude double precision,
  battery_pct int,
  message text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
)
```

## Rewards

```sql
rewards (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  title text not null,
  point_cost int not null,
  created_by uuid references users(id),
  active boolean not null default true,
  created_at timestamptz not null default now()
)

reward_ledger (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id),
  user_id uuid references users(id),
  points int not null,               -- positive = earned, negative = spent
  reason text not null,
  related_type text,                 -- 'task_completion' | 'redemption' | 'bonus' | 'penalty'
  related_id uuid,
  created_at timestamptz not null default now()
)

redemptions (
  id uuid primary key default gen_random_uuid(),
  reward_id uuid references rewards(id),
  user_id uuid references users(id),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  approved_by uuid references users(id),
  created_at timestamptz not null default now()
)
```

## Indexing notes

- Composite index `(family_id, start_at)` on `events`, `(family_id, due_date, due_time)` on `tasks`, `(family_id, scheduled_for)` on `notifications` — these are the hot query paths for the dashboards.
- `locations` should be a hypertable-style pattern (partition by month) or purged/downsampled on a schedule — this table grows fastest by far.
