// child-sign-in
//
// POST { child_id, pin }
//
// Closes the last gap in "PIN/biometric against an already-registered
// family device session" (docs/01-product-spec.md §4): a child has no
// email/password, so they can never call signInWithPassword. Instead, the
// device is already authenticated as SOME family member (parent or
// another child) — the caller here — and this function:
//   1. Verifies the caller belongs to the same family as the target child.
//   2. Verifies the PIN against the child's pin_hash (set by a parent via
//      AuthRepository.setChildPin).
//   3. Mints a one-time magic-link token for the child's auth identity via
//      the Admin API and returns its hash. The client redeems it with
//      supabase.auth.verifyOTP(type: magiclink, tokenHash: ...), which
//      replaces the device's active session with the child's — a real
//      Supabase session, so RLS (`sender_id = auth.uid()`, etc.) sees the
//      child as themselves, not as whoever was signed in a moment ago.
//
// The child never has a password and this never emails anyone — the
// magic-link mechanism is reused purely as Supabase's supported way to
// mint a session for a user without one.

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

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

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

  const { data: callerRow } = await callerClient
    .from('users')
    .select('id, family_id')
    .eq('id', callerAuthUser.id)
    .maybeSingle();
  if (!callerRow?.family_id) return json(403, { error: 'caller has no family membership' });

  const body = await req.json().catch(() => null);
  const childId: string | undefined = body?.child_id;
  const pin: string | undefined = body?.pin;
  if (!childId || !pin) return json(400, { error: 'child_id and pin are required' });

  const { data: child } = await admin
    .from('users')
    .select('id, family_id, role, pin_hash')
    .eq('id', childId)
    .maybeSingle();

  if (!child || child.family_id !== callerRow.family_id) {
    return json(404, { error: 'child not found in your family' });
  }
  if (child.role !== 'child') {
    return json(400, { error: 'target user is not a child account' });
  }
  if (!child.pin_hash) {
    return json(409, { error: 'no PIN set for this child yet — a parent must set one first' });
  }
  if ((await sha256Hex(pin)) !== child.pin_hash) {
    return json(403, { error: 'incorrect PIN' });
  }

  const { data: childAuthUser, error: getUserError } = await admin.auth.admin.getUserById(childId);
  if (getUserError || !childAuthUser?.user?.email) {
    return json(500, { error: 'could not resolve child identity' });
  }

  const { data: linkData, error: linkError } = await admin.auth.admin.generateLink({
    type: 'magiclink',
    email: childAuthUser.user.email,
  });
  if (linkError || !linkData?.properties?.hashed_token) {
    return json(500, { error: `could not create session: ${linkError?.message}` });
  }

  await admin.from('audit_log').insert({
    family_id: callerRow.family_id,
    actor_id: callerAuthUser.id,
    action: 'child_signed_in',
    target_type: 'users',
    target_id: childId,
  });

  return json(200, { hashed_token: linkData.properties.hashed_token });
});
