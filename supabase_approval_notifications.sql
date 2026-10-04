-- Tracks whether an approved visitor has been told about their approval.
--
--   approval_email_sent_at     — set by the notify-approval Edge Function once
--                                Resend accepts the email. Also its idempotency
--                                guard: the function won't re-send unless the
--                                admin explicitly asks for a resend (force).
--   approval_email_error       — last Resend/validation error, cleared on success,
--                                so the admin panel can show why an email failed.
--   approval_whatsapp_sent_at  — set from admin.html when the admin clicks the
--                                "Notify on WhatsApp" button (click-to-chat, so
--                                this records the click, not confirmed delivery).
--
-- All nullable, no new table, so no new RLS policies are needed: the function
-- writes with the service role, and admin.html writes approval_whatsapp_sent_at
-- under the same visitors UPDATE policy the Approve button already uses.

alter table public.visitors
  add column if not exists approval_email_sent_at timestamptz,
  add column if not exists approval_email_error text,
  add column if not exists approval_whatsapp_sent_at timestamptz;
