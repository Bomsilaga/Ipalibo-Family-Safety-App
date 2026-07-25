-- Device heartbeat + uninstall-protection state.
--
-- Context (docs/06-deviations.md "Uninstall protection"): no App Store
-- app can prevent its own deletion on iOS, and on Android doing so needs
-- device-owner provisioning that a family app shouldn't require. So the
-- app doesn't try to block removal — it makes removal *visible*. A child
-- device that stops checking in is exactly the signal a parent needs,
-- and it covers the cases blocking never could anyway: app deleted,
-- phone powered off, permissions revoked, phone left at a friend's.
--
-- `devices` already existed but nothing ever wrote to it.

-- A stable per-install id so a reinstall or a second device shows up as
-- its own row instead of overwriting the first. Generated client-side and
-- kept in secure storage.
alter table public.devices add column if not exists install_id text;

-- Upsert target for the heartbeat. Partial, because rows predating this
-- migration have a null install_id (none exist today, but the constraint
-- has to tolerate them).
create unique index if not exists devices_user_install_idx
  on public.devices (user_id, install_id)
  where install_id is not null;

-- Heartbeat queries are "everyone in my family, most stale first".
create index if not exists devices_family_last_sync_idx
  on public.devices (family_id, last_sync_at desc);

-- Parents watch this list live — a device going quiet is the whole point,
-- so it can't wait for a screen rebuild.
alter publication supabase_realtime add table public.devices;
alter publication supabase_realtime add table public.device_restrictions;

-- The parent records here that they've completed the OS-level lockdown on
-- a child's device (iOS Screen Time / Android Family Link). It's an
-- attestation, not an enforcement: the switch lives in the OS, outside
-- any app's reach. Storing it lets the app stop nagging, show the child
-- what applies to them (a store-review disclosure requirement, already
-- covered by the existing select policy), and log who confirmed it.
--
-- restriction_type = 'uninstall_protection', config:
--   { "platform": "ios"|"android", "method": "screen_time"|"family_link",
--     "confirmed_by": <uuid>, "confirmed_at": <timestamptz>,
--     "device_install_id": <text> }
--
-- No new table: device_restrictions already has the right shape and RLS
-- (child sees their own, parents manage) from migration ...000007.
comment on table public.device_restrictions is
  'Parent-configured restrictions per child. restriction_type ''uninstall_protection'' records that OS-level delete protection was set up on a device; enforcement lives in the OS, not here.';
