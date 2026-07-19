// unlock-code
//
// Handles the parent-side and child-side of the unlock lifecycle
// (docs/01-product-spec.md §8). Two actions:
//
//   POST { action: "generate", request_id }  — parent approves a pending
//     unlock_request: generates a CSPRNG 6-digit code, stores only its
//     hash, 5-minute expiry, marks the request approved, notifies the
//     child, writes the audit log.
//
//   POST { action: "redeem", request_id, code } — child redeems the code:
//     validated server-side against the hash with attempt counting (max 5)
//     and expiry; single-use (code_used_at set on success); audit-logged.
//
// All of this lives server-side because code_hash generation/validation
// and attempt_count must be tamper-proof (docs/03-architecture.md §3).

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

const MAX_ATTEMPTS = 5;
const CODE_TTL_MS = 5 * 60 * 1000;

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function caller(req: Request) {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return null;
  const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
  } = await client.auth.getUser();
  if (!user) return null;
  const { data: row } = await client
    .from('users')
    .select('id, family_id, role')
    .eq('id', user.id)
    .maybeSingle();
  return row;
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
  const me = await caller(req);
  if (!me) return json(401, { error: 'invalid session' });

  const body = await req.json().catch(() => null);
  const action = body?.action;
  const requestId = body?.request_id;
  if (!requestId) return json(400, { error: 'request_id is required' });

  const { data: request } = await admin
    .from('unlock_requests')
    .select('*')
    .eq('id', requestId)
    .maybeSingle();
  if (!request || request.family_id !== me.family_id) {
    return json(404, { error: 'unlock request not found' });
  }

  if (action === 'generate') {
    if (me.role !== 'parent') return json(403, { error: 'only a parent can approve' });
    if (request.status !== 'pending') return json(409, { error: `request is ${request.status}` });

    const code = String(crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000).padStart(6, '0');
    const expiresAt = new Date(Date.now() + CODE_TTL_MS).toISOString();

    await admin
      .from('unlock_requests')
      .update({
        status: 'approved',
        reviewed_by: me.id,
        reviewed_at: new Date().toISOString(),
        code_hash: await sha256Hex(`${requestId}:${code}`),
        code_expires_at: expiresAt,
        attempt_count: 0,
      })
      .eq('id', requestId);

    await admin.from('notifications').insert({
      family_id: me.family_id,
      user_id: request.child_id,
      category: 'unlock_request',
      title: 'Unlock approved',
      body: 'Your parent approved your unlock request. Enter the code they share with you.',
      related_type: 'unlock_request',
      related_id: requestId,
      scheduled_for: new Date().toISOString(),
    });

    await admin.from('audit_log').insert({
      family_id: me.family_id,
      actor_id: me.id,
      action: 'unlock_request_approved',
      target_type: 'unlock_request',
      target_id: requestId,
      metadata: { child_id: request.child_id, expires_at: expiresAt },
    });

    // The plaintext code is returned once, to the approving parent only —
    // they hand it to the child out-of-band (or read it aloud). Never stored.
    return json(200, { code, expires_at: expiresAt });
  }

  if (action === 'redeem') {
    if (me.id !== request.child_id) return json(403, { error: 'only the requesting child can redeem' });
    if (request.status !== 'approved') return json(409, { error: `request is ${request.status}` });
    if (request.code_used_at) return json(409, { error: 'code already used' });
    if (request.code_expires_at && new Date(request.code_expires_at) < new Date()) {
      await admin.from('unlock_requests').update({ status: 'expired' }).eq('id', requestId);
      return json(410, { error: 'code expired' });
    }
    if (request.attempt_count >= MAX_ATTEMPTS) {
      await admin.from('unlock_requests').update({ status: 'expired' }).eq('id', requestId);
      return json(429, { error: 'too many attempts' });
    }

    const code = body?.code;
    const valid = code && (await sha256Hex(`${requestId}:${code}`)) === request.code_hash;

    if (!valid) {
      await admin
        .from('unlock_requests')
        .update({ attempt_count: request.attempt_count + 1 })
        .eq('id', requestId);
      await admin.from('audit_log').insert({
        family_id: me.family_id,
        actor_id: me.id,
        action: 'unlock_code_attempt_failed',
        target_type: 'unlock_request',
        target_id: requestId,
        metadata: { attempt: request.attempt_count + 1 },
      });
      return json(403, { error: 'invalid code', attempts_left: MAX_ATTEMPTS - request.attempt_count - 1 });
    }

    await admin
      .from('unlock_requests')
      .update({ code_used_at: new Date().toISOString() })
      .eq('id', requestId);
    await admin.from('audit_log').insert({
      family_id: me.family_id,
      actor_id: me.id,
      action: 'unlock_code_redeemed',
      target_type: 'unlock_request',
      target_id: requestId,
    });
    return json(200, { unlocked: true });
  }

  if (action === 'reject') {
    if (me.role !== 'parent') return json(403, { error: 'only a parent can reject' });
    if (request.status !== 'pending') return json(409, { error: `request is ${request.status}` });

    await admin
      .from('unlock_requests')
      .update({
        status: 'rejected',
        reviewed_by: me.id,
        reviewed_at: new Date().toISOString(),
      })
      .eq('id', requestId);

    await admin.from('notifications').insert({
      family_id: me.family_id,
      user_id: request.child_id,
      category: 'unlock_request',
      title: 'Unlock request declined',
      body: 'Your parent declined this unlock request.',
      related_type: 'unlock_request',
      related_id: requestId,
      scheduled_for: new Date().toISOString(),
    });

    await admin.from('audit_log').insert({
      family_id: me.family_id,
      actor_id: me.id,
      action: 'unlock_request_rejected',
      target_type: 'unlock_request',
      target_id: requestId,
      metadata: { child_id: request.child_id },
    });

    return json(200, { rejected: true });
  }

  return json(400, { error: 'action must be "generate", "redeem", or "reject"' });
});
