// accept-invite
//
// POST { token, display_name, avatar_color? }
//
// Closes the RLS gap documented in docs/06-deviations.md: joining an
// EXISTING family is never a direct client insert into public.users.
// The invitee signs up (auth), then calls this with the invite token a
// parent shared. The token is validated against family_invites.token_hash
// before the users row is created with the invite's family and role.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'method not allowed' }), { status: 405 });
  }
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'missing authorization' }), { status: 401 });
  }
  const callerClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const {
    data: { user },
  } = await callerClient.auth.getUser();
  if (!user) return new Response(JSON.stringify({ error: 'invalid session' }), { status: 401 });

  const { data: existing } = await admin
    .from('users')
    .select('id')
    .eq('id', user.id)
    .maybeSingle();
  if (existing) {
    return new Response(JSON.stringify({ error: 'already a member of a family' }), { status: 409 });
  }

  const body = await req.json().catch(() => null);
  const token: string | undefined = body?.token;
  const displayName: string | undefined = body?.display_name;
  if (!token || !displayName) {
    return new Response(JSON.stringify({ error: 'token and display_name are required' }), { status: 400 });
  }

  const { data: invite } = await admin
    .from('family_invites')
    .select('*')
    .eq('token_hash', await sha256Hex(token))
    .eq('status', 'pending')
    .maybeSingle();

  if (!invite) {
    return new Response(JSON.stringify({ error: 'invite not found or no longer valid' }), { status: 404 });
  }
  if (new Date(invite.expires_at) < new Date()) {
    await admin.from('family_invites').update({ status: 'expired' }).eq('id', invite.id);
    return new Response(JSON.stringify({ error: 'invite expired' }), { status: 410 });
  }

  const { data: userRow, error: insertError } = await admin
    .from('users')
    .insert({
      id: user.id,
      family_id: invite.family_id,
      role: invite.role,
      display_name: displayName,
      avatar_color: body?.avatar_color ?? '#1976D2',
      created_by: invite.invited_by,
    })
    .select()
    .single();
  if (insertError) {
    return new Response(JSON.stringify({ error: insertError.message }), { status: 500 });
  }

  await admin
    .from('family_invites')
    .update({ status: 'accepted', accepted_by: user.id, accepted_at: new Date().toISOString() })
    .eq('id', invite.id);

  await admin.from('audit_log').insert({
    family_id: invite.family_id,
    actor_id: user.id,
    action: 'invite_accepted',
    target_type: 'family_invite',
    target_id: invite.id,
  });

  return new Response(JSON.stringify(userRow), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
