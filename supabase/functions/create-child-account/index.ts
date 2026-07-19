// create-child-account
//
// Children do not self-register (docs/01-product-spec.md §4): only a
// Parent can create a child account, and the child needs an `auth.users`
// identity because `public.users.id` references it. That requires the
// service role, so this Edge Function does what a direct client insert
// cannot:
//   1. Verify the caller is an authenticated Parent (server-side, never
//      trusting a client-supplied family_id or role).
//   2. Create an auth.users row for the child via the Admin API (no
//      email/password login — children authenticate via PIN/biometric on
//      a shared device, per the product spec).
//   3. Insert the child's public.users row with the same family_id as the
//      calling parent.
//
// docs/03-architecture.md §2: "Every custom Edge Function validates the
// caller's family_id and role server-side before touching data."

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
    return new Response(JSON.stringify({ error: 'missing authorization header' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Client scoped to the caller's own JWT: used only to verify who is
  // calling and pull their family_id/role via RLS-protected reads.
  const callerClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user: callerAuthUser },
    error: callerAuthError,
  } = await callerClient.auth.getUser();

  if (callerAuthError || !callerAuthUser) {
    return new Response(JSON.stringify({ error: 'invalid session' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const { data: callerRow, error: callerRowError } = await callerClient
    .from('users')
    .select('id, family_id, role')
    .eq('id', callerAuthUser.id)
    .maybeSingle();

  if (callerRowError || !callerRow) {
    return new Response(JSON.stringify({ error: 'caller has no family membership' }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
  if (callerRow.role !== 'parent') {
    return new Response(JSON.stringify({ error: 'only a parent can create a child account' }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const body = await req.json().catch(() => null);
  const displayName: string | undefined = body?.display_name;
  const avatarColor: string | undefined = body?.avatar_color;
  const birthYear: number | undefined = body?.birth_year;
  const pin: string | undefined = body?.pin;

  if (!displayName || typeof displayName !== 'string') {
    return new Response(JSON.stringify({ error: 'display_name is required' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Service-role client: bypasses RLS deliberately, scoped to exactly the
  // two writes this function is responsible for.
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  // Children have no email/password login; the Admin API still requires a
  // way to address the row, so we mint a non-deliverable placeholder email
  // under a reserved subdomain. This is an identity anchor only — actual
  // sign-in for children is PIN/biometric against an existing session on a
  // registered family device, per the product spec.
  const placeholderEmail = `child.${crypto.randomUUID()}@device.theipalibos.internal`;

  const { data: createdAuthUser, error: createAuthError } = await adminClient.auth.admin.createUser({
    email: placeholderEmail,
    email_confirm: true,
    user_metadata: { role: 'child', created_by: callerRow.id },
  });

  if (createAuthError || !createdAuthUser?.user) {
    return new Response(
      JSON.stringify({ error: `failed to create child identity: ${createAuthError?.message}` }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  let pinHash: string | null = null;
  if (pin) {
    const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(pin));
    pinHash = Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('');
  }

  const { data: childRow, error: insertError } = await adminClient
    .from('users')
    .insert({
      id: createdAuthUser.user.id,
      family_id: callerRow.family_id,
      role: 'child',
      display_name: displayName,
      avatar_color: avatarColor ?? '#23907F',
      birth_year: birthYear ?? null,
      pin_hash: pinHash,
      created_by: callerRow.id,
    })
    .select()
    .single();

  if (insertError) {
    // Roll back the orphaned auth identity if the users insert failed.
    await adminClient.auth.admin.deleteUser(createdAuthUser.user.id);
    return new Response(JSON.stringify({ error: insertError.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify(childRow), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
