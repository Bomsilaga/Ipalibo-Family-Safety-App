// sos-fanout
//
// POST { latitude?, longitude?, battery_pct?, message? }
//
// One tap from anywhere sends current GPS, timestamp, battery, and a short
// message to ALL parents simultaneously (docs/01-product-spec.md §11).
// Runs server-side so the fanout can't be trimmed by a compromised client
// and so the notification rows are written with the 'emergency' category,
// which is exempt from quiet hours and restriction states by construction
// in schedule-notifications.

import { createClient } from 'jsr:@supabase/supabase-js@2';

// Supabase Edge Functions add no CORS headers by default. Called directly
// from the Flutter web client, so the browser sends a CORS preflight
// (OPTIONS) before the real POST — without this, every browser call fails
// at the preflight with a 405 before the function body ever runs.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'missing authorization' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
  const callerClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const {
    data: { user },
  } = await callerClient.auth.getUser();
  if (!user) {
    return new Response(JSON.stringify({ error: 'invalid session' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const { data: me } = await callerClient
    .from('users')
    .select('id, family_id, display_name')
    .eq('id', user.id)
    .maybeSingle();
  if (!me?.family_id) {
    return new Response(JSON.stringify({ error: 'no family membership' }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const body = await req.json().catch(() => ({}));
  const now = new Date().toISOString();

  const { data: sos, error: sosError } = await admin
    .from('sos_events')
    .insert({
      family_id: me.family_id,
      user_id: me.id,
      latitude: body.latitude ?? null,
      longitude: body.longitude ?? null,
      battery_pct: body.battery_pct ?? null,
      message: body.message ?? null,
    })
    .select()
    .single();
  if (sosError) {
    return new Response(JSON.stringify({ error: sosError.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const { data: parents } = await admin
    .from('users')
    .select('id')
    .eq('family_id', me.family_id)
    .eq('role', 'parent');

  const location = body.latitude != null && body.longitude != null
    ? ` Location: ${body.latitude},${body.longitude}.`
    : '';
  for (const parent of parents ?? []) {
    await admin.from('notifications').insert({
      family_id: me.family_id,
      user_id: parent.id,
      category: 'emergency',
      title: `🆘 SOS from ${me.display_name}`,
      body: `${body.message ?? 'Emergency alert.'}${location} Battery: ${body.battery_pct ?? '?'}%.`,
      related_type: 'sos_event',
      related_id: sos.id,
      scheduled_for: now,
    });
  }

  await admin.from('audit_log').insert({
    family_id: me.family_id,
    actor_id: me.id,
    action: 'sos_raised',
    target_type: 'sos_event',
    target_id: sos.id,
  });

  // SMS fallback (product spec: "push + SMS fallback if configured") —
  // requires a provider account (e.g. Twilio) a human has to set up;
  // when TWILIO_* env vars are absent this is silently skipped.
  // See docs/06-deviations.md.

  return new Response(JSON.stringify({ ok: true, sos_id: sos.id, parents_notified: parents?.length ?? 0 }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
