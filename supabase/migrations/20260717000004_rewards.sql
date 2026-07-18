-- Module 9 (Rewards): rewards, reward_ledger, redemptions + RLS.
-- Created before the tasks migration because tasks.reward_id references
-- rewards(id). Matches docs/02-data-model.md "Rewards" section.

create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  title text not null,
  point_cost int not null,
  created_by uuid references public.users(id),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.reward_ledger (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  user_id uuid references public.users(id),
  points int not null,
  reason text not null,
  related_type text,
  related_id uuid,
  created_at timestamptz not null default now()
);

create index reward_ledger_family_user_idx on public.reward_ledger (family_id, user_id);

create table public.redemptions (
  id uuid primary key default gen_random_uuid(),
  reward_id uuid references public.rewards(id),
  user_id uuid references public.users(id),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  approved_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

alter table public.rewards enable row level security;
alter table public.reward_ledger enable row level security;
alter table public.redemptions enable row level security;

create policy "rewards: family members can view"
on public.rewards for select
to authenticated
using (family_id = public.current_family_id());

create policy "rewards: parents manage the reward economy"
on public.rewards for insert
to authenticated
with check (family_id = public.current_family_id() and public.is_parent());

create policy "rewards: parents update rewards"
on public.rewards for update
to authenticated
using (family_id = public.current_family_id() and public.is_parent())
with check (family_id = public.current_family_id() and public.is_parent());

create policy "rewards: parents delete rewards"
on public.rewards for delete
to authenticated
using (family_id = public.current_family_id() and public.is_parent());

-- Ledger is immutable (product spec §12): visible to the child it belongs
-- to and to parents; only parents insert; no update/delete policy exists,
-- so rows can never be edited or removed by any client role.
create policy "reward_ledger: own rows or parent"
on public.reward_ledger for select
to authenticated
using (
  family_id = public.current_family_id()
  and (user_id = auth.uid() or public.is_parent())
);

create policy "reward_ledger: parents record points"
on public.reward_ledger for insert
to authenticated
with check (family_id = public.current_family_id() and public.is_parent());

create policy "redemptions: own rows or parent"
on public.redemptions for select
to authenticated
using (
  user_id = auth.uid()
  or (
    public.is_parent()
    and exists (
      select 1 from public.rewards r
      where r.id = redemptions.reward_id and r.family_id = public.current_family_id()
    )
  )
);

-- A child requests a redemption of their own; approval flips status and is
-- parent-only (enforced by the update policy).
create policy "redemptions: members request their own"
on public.redemptions for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.rewards r
    where r.id = redemptions.reward_id and r.family_id = public.current_family_id()
  )
);

create policy "redemptions: parents review"
on public.redemptions for update
to authenticated
using (
  public.is_parent()
  and exists (
    select 1 from public.rewards r
    where r.id = redemptions.reward_id and r.family_id = public.current_family_id()
  )
)
with check (
  public.is_parent()
  and exists (
    select 1 from public.rewards r
    where r.id = redemptions.reward_id and r.family_id = public.current_family_id()
  )
);
