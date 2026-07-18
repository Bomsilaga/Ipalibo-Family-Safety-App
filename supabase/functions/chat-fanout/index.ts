// chat-fanout
//
// Invoked by a database webhook on INSERT into public.messages: writes a
// 'chat' notification row for every chat member except the sender, which
// schedule-notifications then delivers (respecting quiet hours). Kept
// separate from realtime — Supabase Realtime handles the live in-app
// stream; this covers members who aren't in the app when a message lands.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'method not allowed' }), { status: 405 });
  }
  // Database webhooks authenticate with the service role key in the
  // Authorization header; reject anything else.
  const auth = req.headers.get('Authorization') ?? '';
  if (auth !== `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`) {
    return new Response(JSON.stringify({ error: 'forbidden' }), { status: 403 });
  }

  const payload = await req.json().catch(() => null);
  const message = payload?.record;
  if (!message || payload?.type !== 'INSERT' || message.type === 'system') {
    return new Response(JSON.stringify({ ok: true, skipped: true }), { status: 200 });
  }

  const { data: chat } = await admin
    .from('chats')
    .select('id, family_id')
    .eq('id', message.chat_id)
    .single();
  const { data: sender } = await admin
    .from('users')
    .select('display_name')
    .eq('id', message.sender_id)
    .single();
  const { data: members } = await admin
    .from('chat_members')
    .select('user_id')
    .eq('chat_id', message.chat_id)
    .neq('user_id', message.sender_id);

  const preview = message.type === 'text'
    ? (message.body ?? '').slice(0, 80)
    : `Sent a ${message.type}`;

  for (const m of members ?? []) {
    await admin.from('notifications').insert({
      family_id: chat!.family_id,
      user_id: m.user_id,
      category: 'chat',
      title: sender?.display_name ?? 'New message',
      body: preview,
      related_type: 'chat',
      related_id: message.chat_id,
      scheduled_for: new Date().toISOString(),
    });
  }

  return new Response(JSON.stringify({ ok: true, notified: members?.length ?? 0 }), { status: 200 });
});
