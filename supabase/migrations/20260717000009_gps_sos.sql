-- Modules 7-8 (GPS Safety + Emergency SOS): locations, safe_zones,
-- safe_zone_events, sos_events + RLS. Matches docs/02-data-model.md.

create table public.locations (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  user_id uuid references public.users(id),
  latitude double precision not null,
  longitude double precision not null,
  accuracy_m double precision,
  battery_pct int,
  recorded_at timestamptz not null default now()
);

-- Hot path is "latest per member" and "history for one member by day";
-- partition/downsample per the data-model note once volume demands it.
create index locations_user_recorded_idx on public.locations (user_id, recorded_at desc);
create index locations_family_recorded_idx on public.locations (family_id, recorded_at desc);

create table public.safe_zones (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  radius_m int not null default 150,
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

create table public.safe_zone_events (
  id uuid primary key default gen_random_uuid(),
  safe_zone_id uuid references public.safe_zones(id) on delete cascade,
  user_id uuid references public.users(id),
  event_type text not null check (event_type in ('arrival','departure')),
  occurred_at timestamptz not null default now()
);

create table public.sos_events (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  user_id uuid references public.users(id),
  latitude double precision,
  longitude double precision,
  battery_pct int,
  message text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

alter table public.locations enable row level security;
alter table public.safe_zones enable row level security;
alter table public.safe_zone_events enable row level security;
alter table public.sos_events enable row level security;

-- "only parents can view history/live location" — a member also sees
-- their own pin (the child must know they're being located: disclosure).
create policy "locations: own or parent"
on public.locations for select
to authenticated
using (
  family_id = public.current_family_id()
  and (user_id = auth.uid() or public.is_parent())
);

-- Devices report their own position. The architecture doc prefers an Edge
-- Function on a battery-conscious interval; the RLS still constrains any
-- direct write to "yourself, in your family" so a compromised client can
-- never spoof another member's location.
create policy "locations: report own position"
on public.locations for insert
to authenticated
with check (family_id = public.current_family_id() and user_id = auth.uid());

create policy "safe_zones: family members can view"
on public.safe_zones for select
to authenticated
using (family_id = public.current_family_id());

create policy "safe_zones: parents manage"
on public.safe_zones for insert
to authenticated
with check (family_id = public.current_family_id() and public.is_parent());

create policy "safe_zones: parents update"
on public.safe_zones for update
to authenticated
using (family_id = public.current_family_id() and public.is_parent())
with check (family_id = public.current_family_id() and public.is_parent());

create policy "safe_zones: parents delete"
on public.safe_zones for delete
to authenticated
using (family_id = public.current_family_id() and public.is_parent());

create policy "safe_zone_events: own or parent"
on public.safe_zone_events for select
to authenticated
using (
  exists (
    select 1 from public.safe_zones z
    where z.id = safe_zone_events.safe_zone_id
      and z.family_id = public.current_family_id()
  )
  and (user_id = auth.uid() or public.is_parent())
);

create policy "safe_zone_events: device records own transitions"
on public.safe_zone_events for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.safe_zones z
    where z.id = safe_zone_events.safe_zone_id
      and z.family_id = public.current_family_id()
  )
);

-- SOS: everyone in the family sees active SOS events (all parents are
-- alerted; the sender sees their own), anyone can raise one, and only a
-- parent resolves it.
create policy "sos_events: family members can view"
on public.sos_events for select
to authenticated
using (family_id = public.current_family_id());

create policy "sos_events: any member can raise SOS"
on public.sos_events for insert
to authenticated
with check (family_id = public.current_family_id() and user_id = auth.uid());

create policy "sos_events: parents resolve"
on public.sos_events for update
to authenticated
using (family_id = public.current_family_id() and public.is_parent())
with check (family_id = public.current_family_id() and public.is_parent());
