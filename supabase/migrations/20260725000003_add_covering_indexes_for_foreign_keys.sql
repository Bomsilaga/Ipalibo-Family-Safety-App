-- Every foreign key the performance advisor reported without a covering
-- index (42 of them). Two reasons this matters here beyond tidiness:
--   * Postgres scans the child table on every parent delete/update, and
--     remove-member deletes by user_id across chat_members, devices and
--     locations.
--   * The junction tables (task_assignees, event_participants,
--     message_receipts, message_reactions, chat_members) have composite
--     PKs whose leading column is the *other* side, so lookups by
--     user_id had no usable index at all.
create index if not exists idx_audit_log_actor_id on public.audit_log(actor_id);
create index if not exists idx_automation_rules_created_by on public.automation_rules(created_by);
create index if not exists idx_automation_rules_family_id on public.automation_rules(family_id);
create index if not exists idx_calls_chat_id on public.calls(chat_id);
create index if not exists idx_calls_created_by on public.calls(created_by);
create index if not exists idx_calls_family_id on public.calls(family_id);
create index if not exists idx_chat_members_user_id on public.chat_members(user_id);
create index if not exists idx_chats_family_id on public.chats(family_id);
create index if not exists idx_device_restrictions_child_id on public.device_restrictions(child_id);
create index if not exists idx_device_restrictions_family_id on public.device_restrictions(family_id);
create index if not exists idx_devices_user_id on public.devices(user_id);
create index if not exists idx_event_attachments_event_id on public.event_attachments(event_id);
create index if not exists idx_event_participants_user_id on public.event_participants(user_id);
create index if not exists idx_events_owner_id on public.events(owner_id);
create index if not exists idx_families_created_by on public.families(created_by);
create index if not exists idx_family_invites_accepted_by on public.family_invites(accepted_by);
create index if not exists idx_family_invites_invited_by on public.family_invites(invited_by);
create index if not exists idx_message_reactions_user_id on public.message_reactions(user_id);
create index if not exists idx_message_receipts_user_id on public.message_receipts(user_id);
create index if not exists idx_messages_reply_to_id on public.messages(reply_to_id);
create index if not exists idx_messages_sender_id on public.messages(sender_id);
create index if not exists idx_redemptions_approved_by on public.redemptions(approved_by);
create index if not exists idx_redemptions_reward_id on public.redemptions(reward_id);
create index if not exists idx_redemptions_user_id on public.redemptions(user_id);
create index if not exists idx_reward_ledger_user_id on public.reward_ledger(user_id);
create index if not exists idx_rewards_created_by on public.rewards(created_by);
create index if not exists idx_rewards_family_id on public.rewards(family_id);
create index if not exists idx_safe_zone_events_safe_zone_id on public.safe_zone_events(safe_zone_id);
create index if not exists idx_safe_zone_events_user_id on public.safe_zone_events(user_id);
create index if not exists idx_safe_zones_created_by on public.safe_zones(created_by);
create index if not exists idx_safe_zones_family_id on public.safe_zones(family_id);
create index if not exists idx_sos_events_family_id on public.sos_events(family_id);
create index if not exists idx_sos_events_user_id on public.sos_events(user_id);
create index if not exists idx_task_assignees_user_id on public.task_assignees(user_id);
create index if not exists idx_task_completions_approved_by on public.task_completions(approved_by);
create index if not exists idx_task_completions_user_id on public.task_completions(user_id);
create index if not exists idx_tasks_created_by on public.tasks(created_by);
create index if not exists idx_tasks_reward_id on public.tasks(reward_id);
create index if not exists idx_trusted_devices_user_id on public.trusted_devices(user_id);
create index if not exists idx_unlock_requests_child_id on public.unlock_requests(child_id);
create index if not exists idx_unlock_requests_reviewed_by on public.unlock_requests(reviewed_by);
create index if not exists idx_users_created_by on public.users(created_by);
