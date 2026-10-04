// Supabase Edge Function: notify-approval
// Emails a visitor (via Resend) that their archive access has been approved.
//
// Called from admin.html right after approveVisitor() succeeds:
//   sb.functions.invoke('notify-approval', { body: { visitor_id, force? } })
//
// Security: deployed WITH JWT verification (the default). The caller's own JWT
// is used to call akt_is_admin() — only admin/superadmin can trigger a send.
// The visitor row is then read/stamped with the service role.
//
// Idempotent: skips if approval_email_sent_at is already set, unless
// force=true (the admin panel's explicit "Resend email" action).
//
// Secrets (set with `supabase secrets set`, never committed):
//   RESEND_API_KEY  — required
//   RESEND_FROM     — optional, defaults to "Apno Ki Talash <admin@apnonkitalash.com>"
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are provided
// automatically by the Edge runtime.

import { createClient } from 'npm:@supabase/supabase-js@2';

const SITE_URL = 'https://apnonkitalash.com/';
const DEFAULT_FROM = 'Apno Ki Talash <admin@apnonkitalash.com>';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

function escHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function firstName(nameEntered: unknown): string {
  const first = String(nameEntered || '').trim().split(/\s+/)[0];
  return first || 'there';
}

function buildEmail(name: string): { subject: string; html: string; text: string } {
  const n = escHtml(name);
  const subject = 'Your Apno Ki Talash access is approved / आपकी रिक्वेस्ट मंज़ूर कर ली गई है';

  const text = [
    `Dear ${name},`,
    '',
    'Your request to join Apno Ki Talash has been approved. You can now sign in at',
    SITE_URL,
    '',
    'Important: after your first sign-in you have 72 hours to find and claim your own profile.',
    'Please claim only your own profile, not a parent\'s or grandparent\'s.',
    '',
    '---',
    '',
    `प्रिय ${name},`,
    '',
    'अपनों की तलाश से जुड़ने के लिए आपकी रिक्वेस्ट मंज़ूर कर ली गई है। अब आप यहाँ साइन इन कर सकते हैं:',
    SITE_URL,
    '',
    'ज़रूरी: पहली बार साइन इन करने के बाद आपके पास अपनी प्रोफ़ाइल ढूँढकर क्लेम करने के लिए 72 घंटे हैं।',
    'कृपया केवल अपनी ही प्रोफ़ाइल क्लेम करें, माता-पिता या दादा-दादी की नहीं।',
    '',
    '— Apno Ki Talash',
  ].join('\n');

  const section = (greeting: string, lines: string[], cta: string, noteTitle: string, note: string) => `
    <p style="margin:0 0 16px 0;font-size:15px;color:#3d3320;line-height:1.7;">${greeting}</p>
    ${lines.map(l => `<p style="margin:0 0 16px 0;font-size:15px;color:#3d3320;line-height:1.7;">${l}</p>`).join('')}
    <p style="margin:0 0 22px 0;text-align:center;">
      <a href="${SITE_URL}" style="display:inline-block;background-color:#2e6e4a;color:#ffffff;text-decoration:none;font-size:15px;font-weight:700;padding:12px 28px;">${cta}</a>
    </p>
    <table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:8px;">
      <tr><td style="background-color:#fdf3d8;border-left:4px solid #c9a84c;padding:14px 18px;">
        <p style="margin:0 0 6px 0;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.12em;color:#7a5c12;">${noteTitle}</p>
        <p style="margin:0;font-size:14px;color:#3d3320;line-height:1.7;">${note}</p>
      </td></tr>
    </table>`;

  const html = `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>${escHtml(subject)}</title></head>
<body style="margin:0;padding:0;background-color:#f5f0e8;font-family:Georgia,'Times New Roman',serif;">
<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f5f0e8;padding:32px 16px;"><tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" border="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #d6c9a8;">
  <tr><td style="background-color:#2e6e4a;padding:28px 36px 22px 36px;text-align:center;">
    <p style="margin:0 0 6px 0;font-size:11px;letter-spacing:0.18em;text-transform:uppercase;color:#c9a84c;">Family Heritage Archive</p>
    <h1 style="margin:0;font-size:26px;font-weight:700;color:#ffffff;">Apno Ki Talash</h1>
    <p style="margin:8px 0 0 0;font-size:12px;color:rgba(255,255,255,0.65);"><a href="${SITE_URL}" style="color:#d6e8dc;text-decoration:none;">apnonkitalash.com</a></p>
  </td></tr>
  <tr><td style="background-color:#dcfce7;border-top:3px solid #2e6e4a;padding:14px 36px;text-align:center;">
    <p style="margin:0;font-size:14px;font-weight:700;color:#166534;">&#10003;&nbsp; Your access has been approved &nbsp;/&nbsp; आपकी रिक्वेस्ट मंज़ूर कर ली गई है</p>
  </td></tr>
  <tr><td style="padding:32px 36px 8px 36px;">
    ${section(
      `Dear ${n},`,
      ['Your request to join <strong>Apno Ki Talash</strong> has been reviewed and approved. You can now sign in and explore the family archive.'],
      'Sign in to the archive',
      'Important — 72 hours to claim',
      'After your <strong>first sign-in</strong>, you have <strong>72 hours</strong> to find and claim your own profile. Please claim only <strong>your own</strong> profile — not a parent\'s or grandparent\'s.',
    )}
  </td></tr>
  <tr><td style="padding:0 36px;"><hr style="border:none;border-top:1px solid #d6c9a8;margin:16px 0 24px 0;"></td></tr>
  <tr><td style="padding:0 36px 24px 36px;">
    ${section(
      `प्रिय ${n},`,
      ['<strong>अपनों की तलाश</strong> से जुड़ने के लिए आपकी रिक्वेस्ट जाँच के बाद मंज़ूर कर ली गई है। अब आप साइन इन करके पारिवारिक संग्रह देख सकते हैं।'],
      'संग्रह में साइन इन करें',
      'ज़रूरी — क्लेम के लिए 72 घंटे',
      '<strong>पहली बार साइन इन</strong> करने के बाद आपके पास अपनी प्रोफ़ाइल ढूँढकर क्लेम करने के लिए <strong>72 घंटे</strong> हैं। कृपया केवल <strong>अपनी ही</strong> प्रोफ़ाइल क्लेम करें — माता-पिता या दादा-दादी की नहीं।',
    )}
  </td></tr>
  <tr><td style="background-color:#f5f0e8;padding:16px 36px;text-align:center;border-top:1px solid #d6c9a8;">
    <p style="margin:0;font-size:12px;color:#7a6c4f;line-height:1.6;">You received this because you registered on apnonkitalash.com.<br>Need help signing in? Visit <a href="${SITE_URL}trouble.html" style="color:#2e6e4a;">apnonkitalash.com/trouble.html</a></p>
  </td></tr>
</table>
</td></tr></table>
</body></html>`;

  return { subject, html, text };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const authHeader = req.headers.get('Authorization') || '';
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;

  // 1. Caller must be admin/superadmin — checked with the caller's own JWT.
  const asCaller = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: isAdmin, error: adminErr } = await asCaller.rpc('akt_is_admin');
  if (adminErr || isAdmin !== true) return json({ error: 'forbidden' }, 403);

  const resendKey = Deno.env.get('RESEND_API_KEY');
  if (!resendKey) return json({ error: 'RESEND_API_KEY not configured' }, 500);

  let body: { visitor_id?: string; force?: boolean };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'bad_json' }, 400);
  }
  const visitorId = String(body.visitor_id || '');
  if (!/^[0-9a-f-]{36}$/i.test(visitorId)) return json({ error: 'bad_visitor_id' }, 400);

  // 2. Load the visitor with the service role.
  const admin = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: visitor, error: loadErr } = await admin
    .from('visitors')
    .select('id,name_entered,email,access_status,is_blocked,approval_email_sent_at')
    .eq('id', visitorId)
    .maybeSingle();
  if (loadErr) return json({ error: 'load_failed', detail: loadErr.message }, 500);
  if (!visitor) return json({ error: 'not_found' }, 404);

  if (visitor.access_status !== 'approved' || visitor.is_blocked) {
    return json({ skipped: 'not_approved' });
  }
  if (visitor.approval_email_sent_at && !body.force) {
    return json({ skipped: 'already_sent', sent_at: visitor.approval_email_sent_at });
  }

  const email = String(visitor.email || '').trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    await admin.from('visitors').update({ approval_email_error: 'No valid email on record' }).eq('id', visitorId);
    return json({ skipped: 'no_email' });
  }

  // 3. Send via Resend.
  const { subject, html, text } = buildEmail(firstName(visitor.name_entered));
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${resendKey}` },
    body: JSON.stringify({
      from: Deno.env.get('RESEND_FROM') || DEFAULT_FROM,
      to: [email],
      subject,
      html,
      text,
    }),
  });
  const resBody = await res.json().catch(() => ({}));

  if (!res.ok) {
    const msg = String((resBody as { message?: string }).message || `Resend HTTP ${res.status}`).slice(0, 500);
    console.error(`[notify-approval] Resend failed for ${visitorId}: ${msg}`);
    await admin.from('visitors').update({ approval_email_error: msg }).eq('id', visitorId);
    return json({ error: 'send_failed', detail: msg }, 502);
  }

  const sentAt = new Date().toISOString();
  await admin
    .from('visitors')
    .update({ approval_email_sent_at: sentAt, approval_email_error: null })
    .eq('id', visitorId);

  return json({ sent: true, sent_at: sentAt, id: (resBody as { id?: string }).id });
});
