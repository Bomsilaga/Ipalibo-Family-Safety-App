-- Module 3 (Tasks/Chores/Homework/Reading): tasks, task_assignees,
-- task_completions + RLS. Matches docs/02-data-model.md.

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  created_by uuid references public.users(id),
  title text not null,
  description text,
  instructions_rich text,
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
  repeat_rule text,
  requires_approval boolean not null default false,
  requires_evidence boolean not null default false,
  reward_id uuid references public.rewards(id),
  penalty_points int,
  book_title text,
  target_minutes int,
  target_pages int,
  subject text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tasks_family_due_idx on public.tasks (family_id, due_date, due_time);

create table public.task_assignees (
  task_id uuid references public.tasks(id) on delete cascade,
  user_id uuid references public.users(id),
  primary key (task_id, user_id)
);

create table public.task_completions (
  id uuid primary key default gen_random_uuid(),
  task_id uuid references public.tasks(id) on delete cascade,
  user_id uuid references public.users(id),
  scheduled_date date not null,
  status text not null default 'upcoming' check (status in ('upcoming','due','completed','late','missed','approved')),
  completed_at timestamptz,
  evidence_photo_url text,
  evidence_note text,
  approved_by uuid references public.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (task_id, user_id, scheduled_date)
);

alter table public.tasks enable row level security;
alter table public.task_assignees enable row level security;
alter table public.task_completions enable row level security;

create policy "tasks: family members can view"
on public.tasks for select
to authenticated
using (family_id = public.current_family_id());

-- "Create tasks/chores: Parent only" (permission matrix).
create policy "tasks: parents create tasks"
on public.tasks for insert
to authenticated
with check (family_id = public.current_family_id() and public.is_parent());

create policy "tasks: parents update tasks"
on public.tasks for update
to authenticated
using (family_id = public.current_family_id() and public.is_parent())
with check (family_id = public.current_family_id() and public.is_parent());

create policy "tasks: parents delete tasks"
on public.tasks for delete
to authenticated
using (family_id = public.current_family_id() and public.is_parent());

create policy "task_assignees: family scope via task"
on public.task_assignees for select
to authenticated
using (
  exists (
    select 1 from public.tasks t
    where t.id = task_assignees.task_id and t.family_id = public.current_family_id()
  )
);

create policy "task_assignees: parents manage assignment"
on public.task_assignees for all
to authenticated
using (
  public.is_parent()
  and exists (
    select 1 from public.tasks t
    where t.id = task_assignees.task_id and t.family_id = public.current_family_id()
  )
)
with check (
  public.is_parent()
  and exists (
    select 1 from public.tasks t
    where t.id = task_assignees.task_id and t.family_id = public.current_family_id()
  )
);

create policy "task_completions: family members can view"
on public.task_completions for select
to authenticated
using (
  exists (
    select 1 from public.tasks t
    where t.id = task_completions.task_id and t.family_id = public.current_family_id()
  )
);

-- The assignee records their own completion; parents can also insert
-- (e.g. marking done on a child's behalf) and update (approval flow —
-- "Approved" only applies when requires_approval is true).
create policy "task_completions: assignee or parent inserts"
on public.task_completions for insert
to authenticated
with check (
  exists (
    select 1 from public.tasks t
    where t.id = task_completions.task_id and t.family_id = public.current_family_id()
  )
  and (user_id = auth.uid() or public.is_parent())
);

create policy "task_completions: own row or parent updates"
on public.task_completions for update
to authenticated
using (
  exists (
    select 1 from public.tasks t
    where t.id = task_completions.task_id and t.family_id = public.current_family_id()
  )
  and (user_id = auth.uid() or public.is_parent())
)
with check (
  exists (
    select 1 from public.tasks t
    where t.id = task_completions.task_id and t.family_id = public.current_family_id()
  )
  and (user_id = auth.uid() or public.is_parent())
);

-- Approval fields are parent-only even though the assignee can update
-- their own completion row (evidence/note): a child must not be able to
-- self-approve an approval-gated task (anti-cheat, product spec §12).
create or replace function public.enforce_completion_approval()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (new.status = 'approved'
      or new.approved_by is distinct from old.approved_by
      or new.approved_at is distinct from old.approved_at)
     and not public.is_parent() then
    raise exception 'only a parent can approve a task completion';
  end if;
  return new;
end;
$$;

create trigger task_completions_approval_guard
before update on public.task_completions
for each row execute function public.enforce_completion_approval();

create trigger tasks_touch_updated_at
before update on public.tasks
for each row execute function public.touch_updated_at();
