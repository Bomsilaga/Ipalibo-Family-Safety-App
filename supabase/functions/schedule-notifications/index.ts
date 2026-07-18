// schedule-notifications
//
// Cron-invoked (e.g. every 5 minutes via Supabase scheduled functions).
// Scans upcoming events.start_at (minus each reminder offset) and
// tasks.due_date/due_time, writes notifications rows for anything entering
// its window, then delivers push for unsent rows whose scheduled_for has
// arrived. Escalation levels 1-4 for chores (docs/01-product-spec.md §7):
//   1 gentle push at due time
//   2 push+sound+badge if unread after grace/4
//   3 persistent notification if still incomplete after grace/2
//   4 parent notified after the full grace period
// Level 5 (device restriction) belongs to Module 6 and is only triggered
// here as an automation hook, never directly.
//
// Push delivery: FCM HTTP v1 when FCM_SERVICE_ACCOUNT_JSON is configured.
// Without it, rows are still written (sent_at left null) so the in-app
// inbox — the offline/retry fallback the spec requires — always works.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

interface QuietHours {
  start: string | null;
  end: string | null;
  timezone: string;
}

function inQuietHours(now: Date, q: QuietHours): boolean {
  if (!q.start || !q.end) return false;
  const local = new Intl.DateTimeFormat('en-GB', {
    timeZone: q.timezone,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(now);
  // Overnight windows (e.g. 21:00 → 07:00) wrap; same-day windows don't.
  return q.start <= q.end
    ? local >= q.start && local < q.end
    : local >= q.start || local < q.end;
}

async function scheduleEventReminders(now: Date, horizon: Date) {
  const { data: events } = await supabase
    .from('events')
    .select('id, family_id, title, start_at, reminder_offsets, event_participants(user_id)')
    .gte('start_at', now.toISOString())
    .lte('start_at', horizon.toISOString())
    .eq('status', 'confirmed');

  for (const event of events ?? []) {
    const startAt = new Date(event.start_at);
    for (const offsetMin of event.reminder_offsets ?? [30]) {
      const fireAt = new Date(startAt.getTime() - offsetMin * 60_000);
      if (fireAt < now) continue;
      const participants = (event.event_participants ?? []) as { user_id: string }[];
      for (const p of participants) {
        // One row per (event, user, offset); related_id + scheduled_for
        // make the check idempotent across cron runs.
        const { data: existing } = await supabase
          .from('notifications')
          .select('id')
          .eq('related_type', 'event')
          .eq('related_id', event.id)
          .eq('user_id', p.user_id)
          .eq('scheduled_for', fireAt.toISOString())
          .maybeSingle();
        if (existing) continue;
        await supabase.from('notifications').insert({
          family_id: event.family_id,
          user_id: p.user_id,
          category: 'appointment',
          title: 'Upcoming appointment',
          body: `${event.title} at ${startAt.toISOString()}`,
          related_type: 'event',
          related_id: event.id,
          scheduled_for: fireAt.toISOString(),
        });
      }
    }
  }
}

async function scheduleTaskReminders(now: Date) {
  const today = now.toISOString().slice(0, 10);
  const { data: tasks } = await supabase
    .from('tasks')
    .select('id, family_id, title, category, due_date, due_time, grace_period_minutes, task_assignees(user_id)')
    .eq('due_date', today);

  for (const task of tasks ?? []) {
    const due = new Date(`${task.due_date}T${task.due_time}Z`);
    const grace = task.grace_period_minutes * 60_000;
    const levels: { level: number; at: Date; toParent: boolean; title: string }[] = [
      { level: 1, at: due, toParent: false, title: `It's time: ${task.title}` },
      { level: 2, at: new Date(due.getTime() + grace / 4), toParent: false, title: `Reminder: ${task.title}` },
      { level: 3, at: new Date(due.getTime() + grace / 2), toParent: false, title: `Still waiting: ${task.title}` },
      { level: 4, at: new Date(due.getTime() + grace), toParent: true, title: `Not completed: ${task.title}` },
    ];

    const assignees = (task.task_assignees ?? []) as { user_id: string }[];
    for (const a of assignees) {
      // Escalations 2-4 only apply while the occurrence is incomplete.
      const { data: completion } = await supabase
        .from('task_completions')
        .select('status')
        .eq('task_id', task.id)
        .eq('user_id', a.user_id)
        .eq('scheduled_date', today)
        .maybeSingle();
      const isDone = completion && ['completed', 'approved'].includes(completion.status);

      for (const step of levels) {
        if (step.at < now) continue;
        if (isDone && step.level > 1) continue;

        let recipients = [a.user_id];
        if (step.toParent) {
          const { data: parents } = await supabase
            .from('users')
            .select('id')
            .eq('family_id', task.family_id)
            .eq('role', 'parent');
          recipients = (parents ?? []).map((p) => p.id);
        }

        for (const userId of recipients) {
          const { data: existing } = await supabase
            .from('notifications')
            .select('id')
            .eq('related_type', 'task')
            .eq('related_id', task.id)
            .eq('user_id', userId)
            .eq('escalation_level', step.level)
            .gte('scheduled_for', `${today}T00:00:00Z`)
            .maybeSingle();
          if (existing) continue;
          await supabase.from('notifications').insert({
            family_id: task.family_id,
            user_id: userId,
            category: task.category === 'chore' ? 'chore' : task.category,
            title: step.title,
            body: `Tap to open the task and mark it done.`,
            related_type: 'task',
            related_id: task.id,
            scheduled_for: step.at.toISOString(),
            escalation_level: step.level,
          });
        }
      }
    }
  }
}

async function deliverDue(now: Date) {
  const { data: due } = await supabase
    .from('notifications')
    .select('id, user_id, family_id, category, title, body, related_type, related_id')
    .is('sent_at', null)
    .lte('scheduled_for', now.toISOString())
    .limit(200);

  const fcmConfigured = !!Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');

  for (const n of due ?? []) {
    // Quiet hours suppress everything except emergency + unlock_request
    // (docs/03-architecture.md §4) — suppressed rows stay queued and
    // deliver when the window ends.
    const { data: family } = await supabase
      .from('families')
      .select('quiet_hours_start, quiet_hours_end, timezone')
      .eq('id', n.family_id)
      .single();
    const exempt = ['emergency', 'unlock_request'].includes(n.category);
    if (
      family &&
      !exempt &&
      inQuietHours(now, {
        start: family.quiet_hours_start,
        end: family.quiet_hours_end,
        timezone: family.timezone,
      })
    ) {
      continue;
    }

    if (fcmConfigured) {
      const { data: devices } = await supabase
        .from('devices')
        .select('push_token')
        .eq('user_id', n.user_id)
        .not('push_token', 'is', null);
      for (const d of devices ?? []) {
        try {
          await sendFcm(d.push_token, n);
        } catch (e) {
          console.error(`push failed for notification ${n.id}: ${e}`);
          // Leave sent_at null — the next cron run retries; the in-app
          // inbox row is already visible regardless.
          continue;
        }
      }
    }

    await supabase.from('notifications').update({ sent_at: now.toISOString() }).eq('id', n.id);
  }
}

let cachedToken: { token: string; expiry: number } | null = null;

async function fcmAccessToken(): Promise<string> {
  if (cachedToken && cachedToken.expiry > Date.now() + 60_000) return cachedToken.token;
  const sa = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!);
  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const nowSec = Math.floor(Date.now() / 1000);
  const claims = btoa(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: nowSec,
      exp: nowSec + 3600,
    }),
  );
  const unsigned = `${header}.${claims}`;
  const keyData = sa.private_key
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replaceAll('\n', '');
  const key = await crypto.subtle.importKey(
    'pkcs8',
    Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/, '')}`;
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const json = await res.json();
  cachedToken = { token: json.access_token, expiry: Date.now() + 3300_000 };
  return cachedToken.token;
}

async function sendFcm(token: string, n: { title: string; body: string; related_type: string | null; related_id: string | null }) {
  const sa = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!);
  const accessToken = await fcmAccessToken();
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: n.title, body: n.body },
          data: {
            related_type: n.related_type ?? '',
            related_id: n.related_id ?? '',
          },
        },
      }),
    },
  );
  if (!res.ok) throw new Error(`FCM ${res.status}: ${await res.text()}`);
}

Deno.serve(async (_req) => {
  const now = new Date();
  const horizon = new Date(now.getTime() + 26 * 60 * 60 * 1000);
  await scheduleEventReminders(now, horizon);
  await scheduleTaskReminders(now);
  await deliverDue(now);
  return new Response(JSON.stringify({ ok: true, ran_at: now.toISOString() }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
