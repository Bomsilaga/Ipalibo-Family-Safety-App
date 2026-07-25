-- Security-advisor cleanup. Two distinct problems:
--
-- 1. Trigger functions were reachable as SECURITY DEFINER RPCs
--    (/rest/v1/rpc/*). Postgres invokes triggers on the table without
--    consulting EXECUTE grants, so revoking costs nothing and removes a
--    set of privileged entry points from the public API surface.
--
-- 2. RLS helper functions were executable by `anon`. Revoking from `anon`
--    alone does nothing, because Postgres grants EXECUTE to PUBLIC on new
--    functions by default and anon inherits it — the grant has to be
--    removed from PUBLIC and handed back only to the roles that need it.
--    `authenticated` must keep EXECUTE: these are called from inside RLS
--    policy expressions, which Postgres evaluates as the querying role,
--    so revoking there would break every family-scoped policy.

revoke all on function public.enforce_users_guardrails() from public, anon, authenticated;
revoke all on function public.enforce_completion_approval() from public, anon, authenticated;
revoke all on function public.enforce_message_update_rules() from public, anon, authenticated;
revoke all on function public.touch_updated_at() from public, anon, authenticated;
revoke all on function public.trigger_chat_fanout() from public, anon, authenticated;
revoke all on function public.create_family_group_chat() from public, anon, authenticated;
revoke all on function public.join_family_group_chat() from public, anon, authenticated;

revoke all on function public.current_family_id() from public;
grant execute on function public.current_family_id() to authenticated, service_role;
revoke all on function public.current_role() from public;
grant execute on function public.current_role() to authenticated, service_role;
revoke all on function public.is_parent() from public;
grant execute on function public.is_parent() to authenticated, service_role;
revoke all on function public.is_chat_member(uuid) from public;
grant execute on function public.is_chat_member(uuid) to authenticated, service_role;
revoke all on function public.is_event_participant(uuid) from public;
grant execute on function public.is_event_participant(uuid) to authenticated, service_role;
revoke all on function public.event_owner_or_parent(uuid) from public;
grant execute on function public.event_owner_or_parent(uuid) to authenticated, service_role;
revoke all on function public.family_id_of_event(uuid) from public;
grant execute on function public.family_id_of_event(uuid) to authenticated, service_role;

-- 3. `families` INSERT was `with check (true)`, so a signed-in user could
--    create a family row attributed to somebody else by passing an
--    arbitrary created_by. Creating your *own* family is legitimate for
--    any authenticated user (it's the founder bootstrap), so pin the row
--    to the caller rather than forbidding the insert.
drop policy if exists "families: authenticated users can create a family" on public.families;
create policy "families: authenticated users can create their own family"
on public.families for insert
to authenticated
with check (created_by = auth.uid());
