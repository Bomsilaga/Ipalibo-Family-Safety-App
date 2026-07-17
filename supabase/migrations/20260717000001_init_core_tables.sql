-- Module 1 (Foundation): families, users, devices, trusted_devices + RLS.
-- Matches docs/02-data-model.md "Core" section.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  avatar_url text,
  timezone text not null default 'Australia/Melbourne',
  quiet_hours_start time,
  quiet_hours_end time,
  created_at timestamptz not null default now()
);

create table public.users (
  id uuid primary key references auth.users(id),
  family_id uuid references public.families(id),
  role text not null check (role in ('parent', 'child')),
  display_name text not null,
  avatar_color text not null,
  avatar_url text,
  birth_year int,
  pin_hash text,
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id),
  family_id uuid references public.families(id),
  os text check (os in ('ios', 'android', 'web')),
  app_version text,
  push_token text,
  device_name text,
  last_sync_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.trusted_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id),
  device_fingerprint text not null,
  trusted_at timestamptz not null default now()
);

create index devices_family_id_idx on public.devices (family_id);
create index users_family_id_idx on public.users (family_id);

-- ---------------------------------------------------------------------------
-- Helper functions
--
-- security definer + a fixed search_path so these read public.users without
-- being subject to the calling role's own RLS on that table (which would
-- otherwise recurse). This is the single source of "who is calling, and
-- what family/role are they" for every RLS policy in the project.
-- ---------------------------------------------------------------------------

create or replace function public.current_family_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select family_id from public.users where id = auth.uid();
$$;

create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.users where id = auth.uid();
$$;

create or replace function public.is_parent()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_role() = 'parent', false);
$$;

-- ---------------------------------------------------------------------------
-- families RLS
-- ---------------------------------------------------------------------------

alter table public.families enable row level security;

create policy "families: members can view their own family"
on public.families for select
to authenticated
using (id = public.current_family_id());

-- Any authenticated user may create a brand-new family row (this is the
-- bootstrap step of registration: create family, then insert your own
-- users row as its founding parent in the same flow). Joining an
-- *existing* family goes through the accept-invite Edge Function using the
-- service role, never a direct client insert into users — see
-- family_invites below.
create policy "families: authenticated users can create a family"
on public.families for insert
to authenticated
with check (true);

create policy "families: parents can update their own family"
on public.families for update
to authenticated
using (id = public.current_family_id() and public.is_parent())
with check (id = public.current_family_id() and public.is_parent());

create policy "families: parents can delete their own family"
on public.families for delete
to authenticated
using (id = public.current_family_id() and public.is_parent());

-- ---------------------------------------------------------------------------
-- users RLS
-- ---------------------------------------------------------------------------

alter table public.users enable row level security;

create policy "users: family members can view each other"
on public.users for select
to authenticated
using (family_id = public.current_family_id());

-- Two legitimate ways a row gets inserted:
--  1. Founder bootstrap: a brand-new authenticated user inserts their own
--     row as the first (and therefore parent) member of a family that has
--     no members yet.
--  2. Parent adding a child: an existing parent inserts a child row scoped
--     to their own family.
-- Joining an existing family as a co-parent via invite is intentionally
-- excluded here and handled server-side (accept-invite Edge Function,
-- service role) so an invite token is actually verified before a stranger
-- can attach themselves to a family's data.
create policy "users: founder bootstrap or parent adds child"
on public.users for insert
to authenticated
with check (
  (
    id = auth.uid()
    and role = 'parent'
    and not exists (
      select 1 from public.users u2 where u2.family_id = users.family_id
    )
  )
  or (
    public.is_parent()
    and family_id = public.current_family_id()
    and role = 'child'
  )
);

-- Self-updates (profile fields) and parent-updates (anyone in the family,
-- e.g. promote/demote, edit a child's profile) are both allowed at the RLS
-- layer; a trigger below blocks a non-parent from changing role/family_id
-- and blocks demoting/removing a family's last parent.
create policy "users: self or parent can update"
on public.users for update
to authenticated
using (family_id = public.current_family_id() and (id = auth.uid() or public.is_parent()))
with check (family_id = public.current_family_id() and (id = auth.uid() or public.is_parent()));

create policy "users: parents can remove a member"
on public.users for delete
to authenticated
using (family_id = public.current_family_id() and public.is_parent());

-- A non-parent must never be able to grant themselves the parent role or
-- move themselves into a different family, and a family must always keep
-- at least one parent (product spec §4 "Parent promotion / demotion").
create or replace function public.enforce_users_guardrails()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' then
    if new.role <> old.role or new.family_id is distinct from old.family_id then
      if not public.is_parent() then
        raise exception 'only a parent can change role or family membership';
      end if;
    end if;

    if old.role = 'parent' and new.role = 'child' then
      if not exists (
        select 1 from public.users u
        where u.family_id = old.family_id
          and u.role = 'parent'
          and u.id <> old.id
      ) then
        raise exception 'a family must always retain at least one parent';
      end if;
    end if;
  end if;

  if tg_op = 'DELETE' then
    if old.role = 'parent' and not exists (
      select 1 from public.users u
      where u.family_id = old.family_id
        and u.role = 'parent'
        and u.id <> old.id
    ) then
      raise exception 'a family must always retain at least one parent';
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

create trigger users_guardrails
before update or delete on public.users
for each row execute function public.enforce_users_guardrails();

-- ---------------------------------------------------------------------------
-- devices RLS
-- ---------------------------------------------------------------------------

alter table public.devices enable row level security;

create policy "devices: owner or parent can view"
on public.devices for select
to authenticated
using (user_id = auth.uid() or (public.is_parent() and family_id = public.current_family_id()));

create policy "devices: owner can register their own device"
on public.devices for insert
to authenticated
with check (user_id = auth.uid() and family_id = public.current_family_id());

create policy "devices: owner or parent can update"
on public.devices for update
to authenticated
using (user_id = auth.uid() or (public.is_parent() and family_id = public.current_family_id()))
with check (family_id = public.current_family_id());

create policy "devices: owner or parent can remove"
on public.devices for delete
to authenticated
using (user_id = auth.uid() or (public.is_parent() and family_id = public.current_family_id()));

-- ---------------------------------------------------------------------------
-- trusted_devices RLS (personal to the user, never shared, not even with parents)
-- ---------------------------------------------------------------------------

alter table public.trusted_devices enable row level security;

create policy "trusted_devices: owner only"
on public.trusted_devices for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
