// invite-member
//
// POST { email, role }   role: 'parent' | 'child'
//
// The one-step "add a family member" backend. A parent types an email and
// the invitee gets a real email they can click straight into the family —
// no code to read out, no code to type.
//
// It does three things atomically enough to be usable:
//   1. mints an invite code and stores only sha256(code) in family_invites
//      (same contract accept-invite already validates against),
//   2. emails the invitee via the Admin API's inviteUserByEmail, whose link
//      both confirms their address and signs them in, landing them on
//      `${APP_URL}/#/join?code=<code>` where the app auto-redeems,
//   3. returns the code + link regardless, so the parent can still share it
//      over WhatsApp/SMS if the email doesn't arrive.
//
// Point 3 matters: Supabase's built-in SMTP is heavily rate-limited (a
// handful of sends per hour) and this project has no custom SMTP yet, so
// email delivery is best-effort. `emailed` in the response says which
// happened; the UI shows the shareable link either way rather than leaving
// the parent stuck.

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

const APP_URL = Deno.env.get('APP_URL') ?? 'https://ipalibo-family-safety-app.vercel.app';

// No 0/O/1/I — these get read aloud and typed by hand when email fails.
const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function generateCode(): string {
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  return Array.from(bytes).map((b) => CODE_CHARS[b % CODE_CHARS.length]).join('');
}

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
    data: { user: authUser },
  } = await callerClient.auth.getUser();
  if (!authUser) return json(401, { error: 'invalid session' });

  const { data: caller } = await callerClient
    .from('users')
    .select('id, family_id, role')
    .eq('id', authUser.id)
    .maybeSingle();
  if (!caller?.family_id) return json(403, { error: 'caller has no family membership' });
  // Mirrors hasPermission(user, AppAction.inviteMember) — a child must not
  // be able to pull new people into the family.
  if (caller.role !== 'parent') {
    return json(403, { error: 'only a parent can invite family members' });
  }

  const body = await req.json().catch(() => null);
  const email: string | undefined = body?.email?.trim();
  const role: string = body?.role === 'parent' ? 'parent' : 'child';
  if (!email || !email.includes('@')) {
    return json(400, { error: 'a valid email is required' });
  }

  const code = generateCode();
  const link = `${APP_URL}/#/join?code=${code}`;

  const { data: invite, error: inviteError } = await admin
    .from('family_invites')
    .insert({
      family_id: caller.family_id,
      invited_by: caller.id,
      role,
      email,
      token_hash: await sha256Hex(code),
    })
    .select()
    .single();
  if (inviteError) return json(500, { error: inviteError.message });

  // Best-effort — the invite is already valid and shareable without it.
  //
  // Sending is raced against a short timeout rather than simply awaited:
  // Supabase's SMTP round trip regularly took 6-10s, and the parent was
  // left staring at a spinner that whole time even though the code and
  // link were ready almost immediately. If the send lands inside the
  // window we can still report truthfully whether it worked; if it
  // doesn't, we hand it to waitUntil so it completes after the response
  // and return emailed: null, meaning "still sending".
  //
  // `inviteUserByEmail` only works for an address that has never signed
  // up — for anyone already registered it fails outright with
  // "422: A user with this email address has already been registered"
  // and sends nothing at all. That was silently killing invites to
  // relatives who'd previously created an account (or been invited once
  // before), and the parent just saw "couldn't email". For those, a
  // magic-link OTP does the same job: it emails them a link that signs
  // them in and lands them on the same /#/join?code=… redemption route.
  let emailed: boolean | null = null;
  let emailError: string | null = null;

  async function sendInviteEmail(): Promise<void> {
    const invited = await admin.auth.admin.inviteUserByEmail(email!, { redirectTo: link });
    if (!invited.error) {
      emailed = true;
      return;
    }
    const alreadyRegistered = invited.error.status === 422 ||
      /already been registered|email_exists/i.test(invited.error.message);
    if (!alreadyRegistered) {
      emailed = false;
      emailError = invited.error.message;
      return;
    }
    const { error: otpError } = await admin.auth.signInWithOtp({
      email: email!,
      options: { emailRedirectTo: link, shouldCreateUser: false },
    });
    emailed = !otpError;
    if (otpError) emailError = otpError.message;
  }

  const sending = sendInviteEmail().catch((e: unknown) => {
    emailed = false;
    emailError = `${e}`;
  });

  const outcome = await Promise.race([
    sending.then(() => 'sent'),
    new Promise((resolve) => setTimeout(() => resolve('pending'), 2500)),
  ]);
  if (outcome === 'pending') {
    // Keeps the function alive past the response so the email still goes.
    try {
      (globalThis as { EdgeRuntime?: { waitUntil: (p: Promise<unknown>) => void } })
        .EdgeRuntime?.waitUntil(sending);
    } catch (_) {
      // Not fatal: worst case the send is cut short and the parent still
      // has the link to share.
    }
  }

  // Not awaited for the same reason — the parent doesn't need to wait on
  // bookkeeping to see their invite link.
  const audit = admin.from('audit_log').insert({
    family_id: caller.family_id,
    actor_id: caller.id,
    action: 'member_invited',
    target_type: 'family_invite',
    target_id: invite.id,
    metadata: { role, emailed },
  });
  try {
    (globalThis as { EdgeRuntime?: { waitUntil: (p: Promise<unknown>) => void } })
      .EdgeRuntime?.waitUntil(audit);
  } catch (_) {
    await audit;
  }

  return json(200, { code, link, email, role, emailed, email_error: emailError });
});
