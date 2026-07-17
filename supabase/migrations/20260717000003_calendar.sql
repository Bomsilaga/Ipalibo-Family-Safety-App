-- Module 2 (Calendar): events, event_participants, event_attachments + RLS.
-- Matches docs/02-data-model.md "Calendar" section.

create table public.events (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  owner_id uuid references public.users(id),
  title text not null,
  description text,
  category text,
  color text,
  icon text,
  location text,
  latitude double precision,
  longitude double precision,
  start_at timestamptz not null,
  end_at timestamptz,
  all_day boolean not null default false,
  repeat_rule text,
  reminder_offsets int[] default '{30}',
  status text not null default 'confirmed' check (status in ('confirmed','cancelled','tentative')),
  visibility text not null default 'family' check (visibility in ('family','private')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index events_family_start_idx on public.events (family_id, start_at);

create table public.event_participants (
  event_id uuid references public.events(id) on delete cascade,
  user_id uuid references public.users(id),
  primary key (event_id, user_id)
);

create table public.event_attachments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id) on delete cascade,
  file_url text not null,
  file_type text,
  created_at timestamptz not null default now()
);

alter table public.events enable row level security;
alter table public.event_participants enable row level security;
alter table public.event_attachments enable row level security;

-- Private events are visible only to their owner and participants; family
-- events to the whole family (product spec §5 visibility field).
create policy "events: family members can view family events"
on public.events for select
to authenticated
using (
  family_id = public.current_family_id()
  and (
    visibility = 'family'
    or owner_id = auth.uid()
    or exists (
      select 1 from public.event_participants ep
      where ep.event_id = events.id and ep.user_id = auth.uid()
    )
  )
);

create policy "events: members create events in their family"
on public.events for insert
to authenticated
with check (family_id = public.current_family_id());

-- "Parents can edit anyone's events; children can edit only their own"
create policy "events: owner or parent can update"
on public.events for update
to authenticated
using (family_id = public.current_family_id() and (owner_id = auth.uid() or public.is_parent()))
with check (family_id = public.current_family_id() and (owner_id = auth.uid() or public.is_parent()));

create policy "events: owner or parent can delete"
on public.events for delete
to authenticated
using (family_id = public.current_family_id() and (owner_id = auth.uid() or public.is_parent()));

create policy "event_participants: family scope via event"
on public.event_participants for select
to authenticated
using (
  exists (
    select 1 from public.events e
    where e.id = event_participants.event_id
      and e.family_id = public.current_family_id()
  )
);

create policy "event_participants: event owner or parent manages"
on public.event_participants for all
to authenticated
using (
  exists (
    select 1 from public.events e
    where e.id = event_participants.event_id
      and e.family_id = public.current_family_id()
      and (e.owner_id = auth.uid() or public.is_parent())
  )
)
with check (
  exists (
    select 1 from public.events e
    where e.id = event_participants.event_id
      and e.family_id = public.current_family_id()
      and (e.owner_id = auth.uid() or public.is_parent())
  )
);

create policy "event_attachments: family scope via event"
on public.event_attachments for select
to authenticated
using (
  exists (
    select 1 from public.events e
    where e.id = event_attachments.event_id
      and e.family_id = public.current_family_id()
  )
);

create policy "event_attachments: event owner or parent manages"
on public.event_attachments for all
to authenticated
using (
  exists (
    select 1 from public.events e
    where e.id = event_attachments.event_id
      and e.family_id = public.current_family_id()
      and (e.owner_id = auth.uid() or public.is_parent())
  )
)
with check (
  exists (
    select 1 from public.events e
    where e.id = event_attachments.event_id
      and e.family_id = public.current_family_id()
      and (e.owner_id = auth.uid() or public.is_parent())
  )
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger events_touch_updated_at
before update on public.events
for each row execute function public.touch_updated_at();
