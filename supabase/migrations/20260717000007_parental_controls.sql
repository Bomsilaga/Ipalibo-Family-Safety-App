-- Module 6 (Parental Controls & Unlock): device_restrictions,
-- unlock_requests, audit_log + RLS. Matches docs/02-data-model.md.

create table public.device_restrictions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  child_id uuid references public.users(id),
  restriction_type text not null,
  config jsonb not null default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.unlock_requests (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  child_id uuid references public.users(id),
  reason text,
  status text not null default 'pending' check (status in ('pending','approved','temporary','rejected','expired')),
  reviewed_by uuid references public.users(id),
  reviewed_at timestamptz,
  code_hash text,
  code_expires_at timestamptz,
  code_used_at timestamptz,
  attempt_count int not null default 0,
  created_at timestamptz not null default now()
);

create index unlock_requests_family_idx on public.unlock_requests (family_id, created_at desc);

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  actor_id uuid references public.users(id),
  action text not null,
  target_type text,
  target_id uuid,
  metadata jsonb default '{}',
  created_at timestamptz not null default now()
);

create index audit_log_family_idx on public.audit_log (family_id, created_at desc);

alter table public.device_restrictions enable row level security;
alter table public.unlock_requests enable row level security;
alter table public.audit_log enable row level security;

-- The affected child can see what restrictions apply to them (clear
-- in-app disclosure is a store-review requirement); only parents manage.
create policy "device_restrictions: child sees own, parent sees all"
on public.device_restrictions for select
to authenticated
using (
  family_id = public.current_family_id()
  and (child_id = auth.uid() or public.is_parent())
);

create policy "device_restrictions: parents manage"
on public.device_restrictions for insert
to authenticated
with check (family_id = public.current_family_id() and public.is_parent());

create policy "device_restrictions: parents update"
on public.device_restrictions for update
to authenticated
using (family_id = public.current_family_id() and public.is_parent())
with check (family_id = public.current_family_id() and public.is_parent());

create policy "device_restrictions: parents delete"
on public.device_restrictions for delete
to authenticated
using (family_id = public.current_family_id() and public.is_parent());

create policy "unlock_requests: child sees own, parent sees all"
on public.unlock_requests for select
to authenticated
using (
  family_id = public.current_family_id()
  and (child_id = auth.uid() or public.is_parent())
);

-- A child creates their own request. Review/approval and code
-- generation/validation happen exclusively in the unlock-code Edge
-- Function (service role) so code_hash handling and attempt counting
-- can't be tampered with client-side — hence no client update policy at
-- all, not even for parents.
create policy "unlock_requests: child requests unlock"
on public.unlock_requests for insert
to authenticated
with check (family_id = public.current_family_id() and child_id = auth.uid());

-- audit_log: parents read; inserts happen via Edge Functions (service
-- role) and via allowed client actions; NO update or delete policy for
-- any role, including parents — the log is append-only by construction.
create policy "audit_log: parents can view"
on public.audit_log for select
to authenticated
using (family_id = public.current_family_id() and public.is_parent());

create policy "audit_log: members append their own actions"
on public.audit_log for insert
to authenticated
with check (family_id = public.current_family_id() and actor_id = auth.uid());
