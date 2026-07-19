// start-call
//
// POST { chat_id, type? }  (type: 'audio' | 'video', default 'video')
//
// Creates a Daily.co room server-side (the API key never reaches the
// client) and a `calls` row that every family member's device picks up
// live via Realtime — that row is the "incoming call" signal the app
// watches for. Returns the room URL for the caller to join immediately.

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
    .select('id, family_id, display_name')
    .eq('id', callerAuthUser.id)
    .maybeSingle();
  if (!caller?.family_id) return json(403, { error: 'caller has no family membership' });

  const body = await req.json().catch(() => null);
  const chatId: string | undefined = body?.chat_id;
  const type: string = body?.type === 'audio' ? 'audio' : 'video';
  if (!chatId) return json(400, { error: 'chat_id is required' });

  const { data: chat } = await callerClient
    .from('chats')
    .select('id, family_id')
    .eq('id', chatId)
    .maybeSingle();
  if (!chat || chat.family_id !== caller.family_id) {
    return json(404, { error: 'chat not found in your family' });
  }

  const { data: dailyApiKey } = await admin.rpc('get_secret', { secret_name: 'daily_api_key' });
  if (!dailyApiKey) return json(500, { error: 'call service is not configured' });

  const roomName = `ipalibos-${caller.family_id.slice(0, 8)}-${Date.now()}`;
  const roomResponse = await fetch('https://api.daily.co/v1/rooms', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${dailyApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      name: roomName,
      privacy: 'public',
      properties: {
        // Rooms are named per-call and only ever shared via the
        // family-scoped `calls` row (RLS), so a short expiry is enough
        // cleanup without needing a separate reaper job.
        exp: Math.floor(Date.now() / 1000) + 60 * 60 * 2,
        enable_screenshare: true,
        start_video_off: type === 'audio',
        start_audio_off: false,
      },
    }),
  });

  if (!roomResponse.ok) {
    const errText = await roomResponse.text();
    return json(502, { error: `could not create call room: ${errText}` });
  }
  const room = await roomResponse.json();

  const { data: callRow, error: insertError } = await admin
    .from('calls')
    .insert({
      family_id: caller.family_id,
      chat_id: chatId,
      room_name: room.name,
      room_url: room.url,
      type,
      created_by: caller.id,
      status: 'ringing',
    })
    .select()
    .single();

  if (insertError) {
    return json(500, { error: insertError.message });
  }

  await admin.from('audit_log').insert({
    family_id: caller.family_id,
    actor_id: caller.id,
    action: 'call_started',
    target_type: 'calls',
    target_id: callRow.id,
    metadata: { type },
  });

  return json(200, callRow);
});
