// end-call
//
// POST { call_id }
//
// Marks a call ended and deletes the Daily room server-side (tidy — no
// lingering rooms, and the room's short exp would clean it up anyway).
// Any family member can end a call (hang up for everyone), matching a
// normal group-call hang-up model.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') return json(405, { error: 'method not allowed' });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json(401, { error: 'missing authorization' });

  const callerClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const {
    data: { user: callerAuthUser },
  } = await callerClient.auth.getUser();
  if (!callerAuthUser) return json(401, { error: 'invalid session' });

  const { data: caller } = await callerClient
    .from('users')
    .select('id, family_id')
    .eq('id', callerAuthUser.id)
    .maybeSingle();
  if (!caller?.family_id) return json(403, { error: 'caller has no family membership' });

  const body = await req.json().catch(() => null);
  const callId: string | undefined = body?.call_id;
  if (!callId) return json(400, { error: 'call_id is required' });

  const { data: call } = await admin
    .from('calls')
    .select('id, family_id, room_name, status')
    .eq('id', callId)
    .maybeSingle();
  if (!call || call.family_id !== caller.family_id) {
    return json(404, { error: 'call not found in your family' });
  }
  if (call.status === 'ended') {
    return json(200, { ended: true });
  }

  const { data: dailyApiKey } = await admin.rpc('get_secret', { secret_name: 'daily_api_key' });
  if (dailyApiKey) {
    await fetch(`https://api.daily.co/v1/rooms/${call.room_name}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${dailyApiKey}` },
    }).catch(() => {
      // Room deletion is best-effort cleanup — the short exp on every
      // room means a failed delete here just means it expires on its own.
    });
  }

  await admin
    .from('calls')
    .update({ status: 'ended', ended_at: new Date().toISOString() })
    .eq('id', callId);

  return json(200, { ended: true });
});
