-- family_invites: backs the "Family invitation" flow in
-- docs/01-product-spec.md §4. Added here and documented in
-- docs/02-data-model.md per CLAUDE.md ("extend those docs first, then
-- implement"). Acceptance is handled by a future accept-invite Edge
-- Function using the service role — it validates the plaintext token
-- against token_hash, then inserts the invitee's public.users row itself,
-- bypassing the client-side RLS gap this table exists to close.

create table public.family_invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id),
  invited_by uuid not null references public.users(id),
  email text,
  phone text,
  role text not null default 'parent' check (role in ('parent', 'child')),
  token_hash text not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'expired', 'revoked')),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_by uuid references public.users(id),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  constraint family_invites_contact_present check (email is not null or phone is not null)
);

create index family_invites_family_id_idx on public.family_invites (family_id);
create unique index family_invites_pending_token_idx on public.family_invites (token_hash) where status = 'pending';

alter table public.family_invites enable row level security;

-- Only parents manage invites for their own family. The invitee never
-- reads this table directly — they redeem a token through the
-- accept-invite Edge Function, which uses the service role and is not
-- bound by these policies.
create policy "family_invites: parents can view their family's invites"
on public.family_invites for select
to authenticated
using (family_id = public.current_family_id() and public.is_parent());

create policy "family_invites: parents can create invites"
on public.family_invites for insert
to authenticated
with check (
  family_id = public.current_family_id()
  and public.is_parent()
  and invited_by = auth.uid()
);

create policy "family_invites: parents can revoke pending invites"
on public.family_invites for update
to authenticated
using (family_id = public.current_family_id() and public.is_parent())
with check (family_id = public.current_family_id() and public.is_parent());
