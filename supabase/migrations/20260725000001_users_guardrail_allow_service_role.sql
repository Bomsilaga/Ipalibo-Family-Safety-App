-- enforce_users_guardrails was blocking its own Edge Functions.
--
-- The guardrail exists to stop a child reassigning their own role or
-- moving themselves between families, and it does that by calling
-- public.is_parent(), which reads auth.uid(). Service-role connections
-- carry no JWT, so auth.uid() is null, is_parent() returns false, and the
-- trigger raised "only a parent can change role or family membership" for
-- perfectly legitimate parent-initiated writes. remove-member hit this on
-- every call: it sets users.family_id = null, which is exactly the
-- "family membership changed" condition the trigger guards.
--
-- The service role only ever reaches this path through Edge Functions
-- (remove-member, accept-invite, create-child-account), each of which
-- verifies server-side that the caller is an authenticated parent acting
-- inside their own family before it writes anything. Exempting it keeps
-- the property that actually matters — a child still cannot move
-- themselves — while letting the verified-parent path through. The
-- last-parent rules below are deliberately left applying to everyone.
create or replace function public.enforce_users_guardrails()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if tg_op = 'UPDATE' then
    if new.role <> old.role or new.family_id is distinct from old.family_id then
      if auth.role() is distinct from 'service_role' and not public.is_parent() then
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
$function$;
