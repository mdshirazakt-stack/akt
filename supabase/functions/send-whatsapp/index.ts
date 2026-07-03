// Supabase Edge Function: send-whatsapp
// Triggered by a Database Webhook on the `visitors` table (UPDATE events).
// Sends a WhatsApp message via Meta Cloud API when:
//   - access_status changes to 'approved'
//   - access_role is promoted (visitor → moderator/admin)
//
// Environment variables required (set in Supabase Dashboard → Settings → Edge Functions):
//   WHATSAPP_PHONE_NUMBER_ID   — your Meta phone number ID (e.g. 123456789012345)
//   WHATSAPP_ACCESS_TOKEN      — your permanent system user token
//   WHATSAPP_APPROVED_TEMPLATE — template name for approval message (e.g. "akt_access_approved")
//                                Leave blank to use "hello_world" for testing

const GRAPH_API_VERSION = 'v22.0';

// ---------------------------------------------------------------------------
// Normalise Indian mobile to WhatsApp format (country code + 10 digits)
// ---------------------------------------------------------------------------
function normaliseToE164(raw: string): string | null {
  const digits = raw.replace(/\D/g, '');
  if (digits.length === 10) return '91' + digits;              // 9818xxxxxx → 919818xxxxxx
  if (digits.length === 12 && digits.startsWith('91')) return digits;  // 919818xxxxxx
  if (digits.length === 11 && digits.startsWith('0')) return '91' + digits.slice(1); // 09818xxxxxx
  return null;
}

// ---------------------------------------------------------------------------
// Send a WhatsApp template message
// ---------------------------------------------------------------------------
async function sendTemplate(
  to: string,
  templateName: string,
  components: object[] = []
): Promise<{ ok: boolean; status: number; body: unknown }> {
  const phoneNumberId = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID')!;
  const token         = Deno.env.get('WHATSAPP_ACCESS_TOKEN')!;

  const res = await fetch(
    `https://graph.facebook.com/${GRAPH_API_VERSION}/${phoneNumberId}/messages`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        to,
        type: 'template',
        template: {
          name: templateName,
          language: { code: 'en_US' },
          ...(components.length ? { components } : {}),
        },
      }),
    }
  );

  const body = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, body };
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------
Deno.serve(async (req) => {
  // Supabase Database Webhooks send POST with the changed record
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  let payload: { type: string; table: string; record: Record<string, unknown>; old_record: Record<string, unknown> };
  try {
    payload = await req.json();
  } catch {
    return new Response('Bad JSON', { status: 400 });
  }

  const { type, table, record, old_record } = payload;

  // Only process UPDATE events on the visitors table
  if (type !== 'UPDATE' || table !== 'visitors') {
    return new Response(JSON.stringify({ skipped: true }), { status: 200 });
  }

  const mobile = String(record.mobile || '').trim();
  const name   = String(record.name_entered || '').trim() || 'there';
  const to     = normaliseToE164(mobile);

  if (!to) {
    console.warn(`[send-whatsapp] No valid mobile for visitor ${record.id} — skipping`);
    return new Response(JSON.stringify({ skipped: 'no_mobile' }), { status: 200 });
  }

  const templateName = Deno.env.get('WHATSAPP_APPROVED_TEMPLATE') || 'hello_world';
  const messages: Array<{ event: string; result: unknown }> = [];

  // ── 1. Access approved ──────────────────────────────────────────────────
  if (
    record.access_status === 'approved' &&
    old_record.access_status !== 'approved'
  ) {
    // Template components: if your approved template has a {{1}} name parameter,
    // include it here. Remove the components array if your template has no params.
    const result = await sendTemplate(to, templateName, [
      {
        type: 'body',
        parameters: [{ type: 'text', text: name }],
      },
    ]);
    console.log(`[send-whatsapp] approval → ${to}: ${JSON.stringify(result)}`);
    messages.push({ event: 'approved', result });
  }

  // ── 2. Role promoted ────────────────────────────────────────────────────
  const ROLE_RANK: Record<string, number> = { visitor: 1, moderator: 2, admin: 3, superadmin: 4 };
  const oldRole = String(old_record.access_role || 'visitor');
  const newRole = String(record.access_role    || 'visitor');
  if ((ROLE_RANK[newRole] || 0) > (ROLE_RANK[oldRole] || 0)) {
    // Use a separate "role_promoted" template if you have one; falls back to hello_world
    const roleTemplate = Deno.env.get('WHATSAPP_ROLE_TEMPLATE') || templateName;
    const result = await sendTemplate(to, roleTemplate, [
      { type: 'body', parameters: [{ type: 'text', text: name }, { type: 'text', text: newRole }] },
    ]);
    console.log(`[send-whatsapp] role ${oldRole}→${newRole} → ${to}: ${JSON.stringify(result)}`);
    messages.push({ event: 'role_promoted', result });
  }

  if (!messages.length) {
    return new Response(JSON.stringify({ skipped: 'no_trigger_matched' }), { status: 200 });
  }

  return new Response(JSON.stringify({ sent: messages }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
