-- Module 5 (Family Chat): chats, chat_members, messages,
-- message_reactions, message_receipts + RLS. Matches docs/02-data-model.md.

create table public.chats (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families(id),
  type text not null check (type in ('family_group','direct','announcement')),
  created_at timestamptz not null default now()
);

create table public.chat_members (
  chat_id uuid references public.chats(id) on delete cascade,
  user_id uuid references public.users(id),
  primary key (chat_id, user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid references public.chats(id) on delete cascade,
  sender_id uuid references public.users(id),
  type text not null check (type in ('text','image','video','voice','document','system')),
  body text,
  media_url text,
  reply_to_id uuid references public.messages(id),
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create index messages_chat_created_idx on public.messages (chat_id, created_at desc);

create table public.message_reactions (
  message_id uuid references public.messages(id) on delete cascade,
  user_id uuid references public.users(id),
  emoji text not null,
  primary key (message_id, user_id, emoji)
);

create table public.message_receipts (
  message_id uuid references public.messages(id) on delete cascade,
  user_id uuid references public.users(id),
  delivered_at timestamptz,
  read_at timestamptz,
  primary key (message_id, user_id)
);

alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_reactions enable row level security;
alter table public.message_receipts enable row level security;

create or replace function public.is_chat_member(p_chat_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.chat_members cm
    where cm.chat_id = p_chat_id and cm.user_id = auth.uid()
  );
$$;

-- "parents can view all chats" (product spec §2) — a parent sees every
-- chat in the family; others see chats they're a member of.
create policy "chats: members and parents can view"
on public.chats for select
to authenticated
using (
  family_id = public.current_family_id()
  and (public.is_chat_member(id) or public.is_parent())
);

create policy "chats: members create chats in their family"
on public.chats for insert
to authenticated
with check (family_id = public.current_family_id());

create policy "chat_members: visible to fellow members and parents"
on public.chat_members for select
to authenticated
using (
  exists (
    select 1 from public.chats c
    where c.id = chat_members.chat_id
      and c.family_id = public.current_family_id()
      and (public.is_chat_member(c.id) or public.is_parent())
  )
);

create policy "chat_members: self-join family chats or parent manages"
on public.chat_members for insert
to authenticated
with check (
  exists (
    select 1 from public.chats c
    where c.id = chat_members.chat_id and c.family_id = public.current_family_id()
  )
  and (user_id = auth.uid() or public.is_parent())
);

create policy "chat_members: leave or parent removes"
on public.chat_members for delete
to authenticated
using (
  exists (
    select 1 from public.chats c
    where c.id = chat_members.chat_id and c.family_id = public.current_family_id()
  )
  and (user_id = auth.uid() or public.is_parent())
);

create policy "messages: chat members and parents can read"
on public.messages for select
to authenticated
using (
  exists (
    select 1 from public.chats c
    where c.id = messages.chat_id
      and c.family_id = public.current_family_id()
      and (public.is_chat_member(c.id) or public.is_parent())
  )
);

create policy "messages: members send as themselves"
on public.messages for insert
to authenticated
with check (
  sender_id = auth.uid()
  and public.is_chat_member(chat_id)
);

-- Edits by the sender; tombstone deletes (deleted_at) by the sender or by
-- a parent ("parents can remove any message in the family chat"). A
-- trigger keeps this to edit/tombstone semantics — messages are never
-- hard-deleted, so there is deliberately no DELETE policy.
create policy "messages: sender edits, sender or parent tombstones"
on public.messages for update
to authenticated
using (
  exists (
    select 1 from public.chats c
    where c.id = messages.chat_id and c.family_id = public.current_family_id()
  )
  and (sender_id = auth.uid() or public.is_parent())
)
with check (
  exists (
    select 1 from public.chats c
    where c.id = messages.chat_id and c.family_id = public.current_family_id()
  )
  and (sender_id = auth.uid() or public.is_parent())
);

create or replace function public.enforce_message_update_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- A parent who isn't the sender may only tombstone (set deleted_at);
  -- they must not be able to rewrite someone else's words.
  if old.sender_id <> auth.uid() then
    if new.body is distinct from old.body
       or new.media_url is distinct from old.media_url
       or new.type is distinct from old.type then
      raise exception 'only the sender can edit message content';
    end if;
  end if;
  -- No un-deleting: tombstones are permanent for audit purposes.
  if old.deleted_at is not null and new.deleted_at is null then
    raise exception 'a deleted message cannot be restored';
  end if;
  return new;
end;
$$;

create trigger messages_update_rules
before update on public.messages
for each row execute function public.enforce_message_update_rules();

create policy "message_reactions: chat members react"
on public.message_reactions for all
to authenticated
using (
  user_id = auth.uid()
  and exists (
    select 1 from public.messages m
    where m.id = message_reactions.message_id and public.is_chat_member(m.chat_id)
  )
)
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.messages m
    where m.id = message_reactions.message_id and public.is_chat_member(m.chat_id)
  )
);

create policy "message_reactions: visible to chat members and parents"
on public.message_reactions for select
to authenticated
using (
  exists (
    select 1 from public.messages m
    join public.chats c on c.id = m.chat_id
    where m.id = message_reactions.message_id
      and c.family_id = public.current_family_id()
      and (public.is_chat_member(c.id) or public.is_parent())
  )
);

create policy "message_receipts: own receipts"
on public.message_receipts for insert
to authenticated
with check (user_id = auth.uid());

create policy "message_receipts: update own receipts"
on public.message_receipts for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "message_receipts: visible to chat members and parents"
on public.message_receipts for select
to authenticated
using (
  exists (
    select 1 from public.messages m
    join public.chats c on c.id = m.chat_id
    where m.id = message_receipts.message_id
      and c.family_id = public.current_family_id()
      and (public.is_chat_member(c.id) or public.is_parent())
  )
);

-- The family group chat is auto-created with the family and every new
-- member auto-joins it (product spec §9 "family group chat (auto-created
-- per family)").
create or replace function public.create_family_group_chat()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.chats (family_id, type) values (new.id, 'family_group');
  return new;
end;
$$;

create trigger families_create_group_chat
after insert on public.families
for each row execute function public.create_family_group_chat();

create or replace function public.join_family_group_chat()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.chat_members (chat_id, user_id)
  select c.id, new.id from public.chats c
  where c.family_id = new.family_id and c.type = 'family_group'
  on conflict do nothing;
  return new;
end;
$$;

create trigger users_join_group_chat
after insert on public.users
for each row execute function public.join_family_group_chat();
