-- Profile-claim clock now starts at first login AFTER admin approval,
-- not at registration time.
--
-- PROBLEM:
--   visitorClaimDeadline() / profileClaimDeadline() previously based the
--   72-hour (and 7-day "add me") windows on visitor_form_completed_at,
--   which is stamped the moment a brand-new user submits the onboarding
--   form — while their account is still 'pending', awaiting admin
--   approval. If approval took longer than 72h (e.g. the user only comes
--   back a week later), they could already be flagged "claim overdue" —
--   or even auto-treated as needing block — the very first time they were
--   ever able to log in and act on it.
--
-- FIX:
--   New column visitors.claim_clock_started_at is stamped once, by
--   enterVisitor() in auth-flow.js, the first time an approved visitor
--   successfully enters the archive (i.e. completes onboarding AND is not
--   pending/blocked/rejected). It is never overwritten on later logins.
--
--   visitorClaimDeadline() (admin.html) and profileClaimDeadline()
--   (auth-flow.js) now read claim_clock_started_at first, falling back to
--   the old visitor_form_completed_at-based basis for visitors who haven't
--   logged in again since this migration runs. Their next login stamps
--   claim_clock_started_at and gives them a fresh 72h window from that
--   point.
--
-- RUN IN: Supabase SQL Editor (fusairoeiabmqvsbxhfi.supabase.co)

ALTER TABLE public.visitors
  ADD COLUMN IF NOT EXISTS claim_clock_started_at timestamptz;

COMMENT ON COLUMN public.visitors.claim_clock_started_at IS
  'Timestamp of this visitor''s first successful entry into the archive after admin approval. Start of the 72-hour profile-claim window. Set once by enterVisitor() in auth-flow.js; never overwritten thereafter.';

-- No RLS changes needed: visitors already have a self-update policy
-- (auth_user_id = auth.uid()) covering the existing enterVisitor() update,
-- and this just adds one more column to that same row update.
