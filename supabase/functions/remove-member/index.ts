// remove-member
//
// POST { user_id }
//
// Removes someone from the caller's family. Parent-only, and deliberately
// a *detach* rather than a hard delete: public.users.id is referenced by
// messages.sender_id, task_assignees, task_completions, reward_ledger and
// more, so `delete from users` either fails on a foreign key or takes
// family history down with it. Setting family_id = null drops every RLS
// check they'd pass (current_family_id() returns null for them, so no
// family row is visible any more) while leaving the family's own records
// coherent — a chore they completed last month still shows who completed
// it.
//
// Two things are actively cleaned up rather than detached:
//   - devices: push tokens live here, so leaving them would keep pushing
//     family notifications to someone who is no longer in the family.
//   - locations: GPS history is the most sensitive thing a removed member
//     leaves behind, and continuing to hold it fails the child-privacy
//     bar in CLAUDE.md (data minimisation / deletable data). Removal ends
//     tracking, so the trail goes with it.
//
// chat_members is deleted too so they stop receiving family chat.

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
    data: { user: authUser },
  } = await callerClient.auth.getUser();
  if (!authUser) return json(401, { error: 'invalid session' });

  const { data: caller } = await callerClient
    .from('users')
    .select('id, family_id, role')
    .eq('id', authUser.id)
    .maybeSingle();
  if (!caller?.family_id) return json(403, { error: 'caller has no family membership' });
  if (caller.role !== 'parent') {
    return json(403, { error: 'only a parent can remove family members' });
  }

  const body = await req.json().catch(() => null);
  const targetId: string | undefined = body?.user_id;
  if (!targetId) return json(400, { error: 'user_id is required' });
  // Removing yourself here would strand the family with no way back in;
  // leaving is a separate, deliberate action.
  if (targetId === caller.id) {
    return json(400, { error: 'you cannot remove yourself from the family' });
  }

  const { data: target } = await admin
    .from('users')
    .select('id, family_id, role, display_name')
    .eq('id', targetId)
    .maybeSingle();
  if (!target || target.family_id !== caller.family_id) {
    return json(404, { error: 'that member is not in your family' });
  }

  // No "last parent" guard is needed: the caller is themselves a parent,
  // is not the target (rejected above), and stays in the family — so at
  // least one parent always remains after any removal this endpoint
  // permits.

  await admin.from('chat_members').delete().eq('user_id', targetId);
  await admin.from('devices').delete().eq('user_id', targetId);
  await admin.from('locations').delete().eq('user_id', targetId);

  const { error: detachError } = await admin
    .from('users')
    .update({ family_id: null })
    .eq('id', targetId);
  if (detachError) return json(500, { error: detachError.message });

  await admin.from('audit_log').insert({
    family_id: caller.family_id,
    actor_id: caller.id,
    action: 'member_removed',
    target_type: 'user',
    target_id: targetId,
    metadata: { display_name: target.display_name, role: target.role },
  });

  return json(200, { removed: true, user_id: targetId });
});
