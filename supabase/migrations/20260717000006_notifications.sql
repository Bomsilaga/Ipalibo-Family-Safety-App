-- Module 4 (Notifications & Automation): notifications, automation_rules
-- + RLS. Matches docs/02-data-model.md.

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  user_id uuid references public.users(id),
  category text not null check (category in
    ('appointment','chore','homework','reading','unlock_request','gps_alert','chat','announcement','emergency')),
  title text not null,
  body text not null,
  related_type text,
  related_id uuid,
  scheduled_for timestamptz not null,
  sent_at timestamptz,
  read_at timestamptz,
  escalation_level int not null default 1,
  created_at timestamptz not null default now()
);

create index notifications_family_scheduled_idx on public.notifications (family_id, scheduled_for);
create index notifications_user_idx on public.notifications (user_id, scheduled_for desc);

create table public.automation_rules (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  created_by uuid references public.users(id),
  trigger text not null,
  action text not null,
  config jsonb not null default '{}',
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;
alter table public.automation_rules enable row level security;

-- Your inbox is yours; parents can also see children's notifications
-- (they configure the categories and need visibility for escalation).
create policy "notifications: recipient or parent can view"
on public.notifications for select
to authenticated
using (
  family_id = public.current_family_id()
  and (user_id = auth.uid() or public.is_parent())
);

-- Scheduling is server-side (schedule-notifications Edge Function, service
-- role). Clients may insert lightweight in-app notifications for their own
-- family (e.g. an announcement) but the scheduled reminder pipeline never
-- relies on client inserts.
create policy "notifications: members create in-family notifications"
on public.notifications for insert
to authenticated
with check (family_id = public.current_family_id());

-- Recipients mark their own notifications read.
create policy "notifications: recipient updates read state"
on public.notifications for update
to authenticated
using (family_id = public.current_family_id() and user_id = auth.uid())
with check (family_id = public.current_family_id() and user_id = auth.uid());

create policy "automation_rules: parents only"
on public.automation_rules for all
to authenticated
using (family_id = public.current_family_id() and public.is_parent())
with check (family_id = public.current_family_id() and public.is_parent());
