-- Realtime for members and locations.
--
-- Only `messages` and `calls` were in the publication, so anything reading
-- `users` or `locations` was effectively a one-shot fetch that never
-- refreshed. Two visible symptoms:
--
--   * a child who accepted an invite appeared on their own device (fresh
--     load, fresh fetch) but not in the parent's Family tab until the
--     parent fully restarted the app;
--   * Live Location only moved when the screen was rebuilt from scratch.
--
-- Publishing these two lets `.stream()` push changes to every device.
alter publication supabase_realtime add table public.users;
alter publication supabase_realtime add table public.locations;
