-- One-time preview session for users waiting on admin approval (2026-11-15).
--
-- WHAT:
--   A newly registered user is still 'pending' (awaiting admin approval), but
--   gets ONE preview session of the archive straight away. The preview ends
--   when they sign out, or 24 hours after it started — whichever comes first.
--   After that they see the usual "pending approval" message until an admin
--   approves them. During the preview they can do everything an approved
--   visitor can (browse, claim a profile, corrections, suggestions).
--
--   Nothing changes after approval: the 72h claim clock still starts at the
--   first login after approval (claim_clock_started_at — the guard trigger
--   below only lets that be stamped for approved visitors, so a preview never
--   starts it), and block_overdue_unclaimed_visitors() is untouched.
--
-- HOW:
--   visitors.preview_started_at / preview_ended_at, written only by the two
--   SECURITY DEFINER RPCs below (the guard trigger blocks direct browser
--   writes, so a user can't restart or extend their preview).
--   akt_is_visitor() — which every visitor RLS policy relies on — also returns
--   true for a pending, unblocked visitor whose preview is open, so the
--   preview is enforced by the database, not just by the page.
--
-- RUN IN: Supabase SQL Editor (fusairoeiabmqvsbxhfi.supabase.co)
-- Safe to re-run.

alter table public.visitors
  add column if not exists preview_started_at timestamptz,
  add column if not exists preview_ended_at   timestamptz;

comment on column public.visitors.preview_started_at is
  'Start of this pending visitor''s one-time preview session (set once by start_pending_preview()).';
comment on column public.visitors.preview_ended_at is
  'When the preview was ended by signing out (end_pending_preview()). Preview also ends 24h after preview_started_at.';

-- ── akt_is_visitor: approved, OR pending with an open preview ───────────────
create or replace function public.akt_is_visitor()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from public.visitors v
    where (v.auth_user_id = auth.uid() or lower(v.email) = lower(coalesce(auth.email(), '')))
      and coalesce(v.is_blocked, false) = false
      and (
        coalesce(v.access_status, 'approved') = 'approved'
        or (
          v.access_status = 'pending'
          and v.preview_started_at is not null
          and v.preview_ended_at is null
          and now() < v.preview_started_at + interval '24 hours'
        )
      )
  );
$$;

grant execute on function public.akt_is_visitor() to anon, authenticated;

-- ── The caller's own visitor row (same match rule as get_my_visitor) ────────
create or replace function public.akt_my_visitor_id()
returns uuid
language sql
stable
security definer
set search_path to 'public'
as $$
  select v.id
  from public.visitors v
  where v.auth_user_id = auth.uid()
     or lower(v.email) = lower(coalesce(auth.email(), ''))
  order by v.last_seen desc nulls last
  limit 1;
$$;

revoke execute on function public.akt_my_visitor_id() from public, anon;
grant execute on function public.akt_my_visitor_id() to authenticated;

-- ── Start (or resume) the preview ───────────────────────────────────────────
-- Starts the preview the first time it's called for a pending visitor; later
-- calls just report the state. Returns {active, started_at, expires_at}.
create or replace function public.start_pending_preview()
returns json
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  vid uuid := public.akt_my_visitor_id();
  v public.visitors%rowtype;
begin
  if vid is null then
    return json_build_object('active', false);
  end if;

  update public.visitors
     set preview_started_at = now()
   where id = vid
     and access_status = 'pending'
     and coalesce(is_blocked, false) = false
     and preview_started_at is null;

  select * into v from public.visitors where id = vid;

  return json_build_object(
    'active', v.access_status = 'pending'
              and coalesce(v.is_blocked, false) = false
              and v.preview_started_at is not null
              and v.preview_ended_at is null
              and now() < v.preview_started_at + interval '24 hours',
    'started_at', v.preview_started_at,
    'expires_at', v.preview_started_at + interval '24 hours'
  );
end;
$$;

revoke execute on function public.start_pending_preview() from public, anon;
grant execute on function public.start_pending_preview() to authenticated;

-- ── End the preview (called on sign-out) ────────────────────────────────────
create or replace function public.end_pending_preview()
returns void
language sql
security definer
set search_path to 'public'
as $$
  update public.visitors
     set preview_ended_at = now()
   where id = public.akt_my_visitor_id()
     and preview_started_at is not null
     and preview_ended_at is null;
$$;

revoke execute on function public.end_pending_preview() from public, anon;
grant execute on function public.end_pending_preview() to authenticated;

-- ── Guard trigger: same as supabase_visitor_guard_and_claim_clock.sql, plus
--    preview_started_at / preview_ended_at as protected columns ────────────
create or replace function public.akt_guard_visitor_fields()
returns trigger
language plpgsql
security invoker
set search_path to 'public'
as $$
begin
  -- Server-side callers (service_role, postgres/cron, SECURITY DEFINER fns).
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  -- Admins/superadmins edit these from admin.html.
  if public.akt_is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.access_status             := 'pending';
    new.access_role               := 'visitor';
    new.is_blocked                := false;
    new.block_reason              := null;
    new.approved_at               := null;
    new.rejected_at               := null;
    new.admin_notes               := null;
    new.print_free                := false;
    new.claim_revoke_notice       := null;
    new.claim_clock_started_at    := null;
    new.approval_email_sent_at    := null;
    new.approval_email_error      := null;
    new.approval_whatsapp_sent_at := null;
    new.preview_started_at        := null;
    new.preview_ended_at          := null;
    return new;
  end if;

  -- UPDATE: keep protected columns at their current values.
  new.access_status             := old.access_status;
  new.access_role               := old.access_role;
  new.is_blocked                := old.is_blocked;
  new.block_reason              := old.block_reason;
  new.approved_at               := old.approved_at;
  new.rejected_at               := old.rejected_at;
  new.admin_notes               := old.admin_notes;
  new.print_free                := old.print_free;
  new.claim_revoke_notice       := old.claim_revoke_notice;
  new.approval_email_sent_at    := old.approval_email_sent_at;
  new.approval_email_error      := old.approval_email_error;
  new.approval_whatsapp_sent_at := old.approval_whatsapp_sent_at;
  new.preview_started_at        := old.preview_started_at;
  new.preview_ended_at          := old.preview_ended_at;

  -- claim_clock_started_at: enterVisitor() stamps it once, on first entry
  -- after approval. Allow only that null → now() transition (server time, so
  -- a user can't post-date it to dodge the 72h block); never clear/move it.
  if old.claim_clock_started_at is null
     and new.claim_clock_started_at is not null
     and coalesce(old.access_status, 'approved') = 'approved'
     and coalesce(old.is_blocked, false) = false then
    new.claim_clock_started_at := now();
  else
    new.claim_clock_started_at := old.claim_clock_started_at;
  end if;

  return new;
end;
$$;
