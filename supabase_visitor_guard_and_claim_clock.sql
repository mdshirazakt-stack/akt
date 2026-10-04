-- Two fixes on public.visitors (2026-10-04):
--
-- 1. SECURITY: stop non-admins from editing their own access/role fields.
--    visitors_self_update allows any user to UPDATE their own row with no
--    column restriction, and visitors_self_insert lets them choose every
--    column on insert (and access_status even DEFAULTS to 'approved'). So a
--    signed-up user could, from the browser console, set their own
--    access_status='approved', access_role='superadmin', is_blocked=false or
--    print_free=true — skipping approval entirely. RLS can't restrict columns,
--    so a BEFORE trigger enforces it: for a non-admin caller, protected
--    columns are silently kept at their old value (UPDATE) or forced to safe
--    defaults (INSERT). Legitimate self-writes (onboarding form, last_seen,
--    visit_count, profile details) are unaffected — those flows already send
--    the user's existing status values unchanged.
--
--    The trigger is SECURITY INVOKER on purpose: current_user is then the
--    real caller. 'authenticated'/'anon' = a browser request (checked);
--    anything else = service_role (Edge Functions) or postgres (cron job,
--    SECURITY DEFINER functions) and passes through.
--
-- 2. BUG: the 12-hourly cron job block_overdue_unclaimed_visitors() still
--    measured the 72h claim window from REGISTRATION time
--    (visitor_form_completed_at), so a user approved more than 72h after
--    registering was auto-blocked before they ever logged in. The June fix
--    (supabase_claim_clock_login.sql) only changed the admin/login UI, not
--    this function. It now uses claim_clock_started_at only — stamped at the
--    user's first login after approval — and never blocks someone whose
--    clock hasn't started.
--
-- 3. akt_is_admin() gains the same email fallback akt_is_visitor() and
--    akt_is_staff() already have (admins with a null auth_user_id).

-- ── 3. akt_is_admin email fallback ──────────────────────────────────────────
create or replace function public.akt_is_admin()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from public.visitors v
    where (v.auth_user_id = auth.uid() or lower(v.email) = lower(coalesce(auth.email(), '')))
      and v.access_role in ('admin','superadmin')
      and coalesce(v.is_blocked, false) = false
  );
$$;

-- ── 1. Guard protected columns ──────────────────────────────────────────────
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

drop trigger if exists akt_guard_visitor_fields on public.visitors;
create trigger akt_guard_visitor_fields
  before insert or update on public.visitors
  for each row execute function public.akt_guard_visitor_fields();

-- ── 2. Cron: measure the 72h window from first login after approval ────────
create or replace function public.block_overdue_unclaimed_visitors()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  blocked_count integer;
begin
  update public.visitors v
  set
    is_blocked = true,
    access_status = 'blocked',
    block_reason = coalesce(
      nullif(v.block_reason, ''),
      'Auto-blocked: profile not claimed within 72 hours of first login after approval'
    ),
    updated_at = now()
  where coalesce(v.is_blocked, false) = false
    and coalesce(v.access_status, 'approved') = 'approved'
    and coalesce(v.access_role, 'visitor') = 'visitor'
    -- Clock starts at first login AFTER approval; not started = not overdue.
    and v.claim_clock_started_at is not null
    and v.claim_clock_started_at < now() - interval '72 hours'
    and not exists (
      select 1
      from public.profile_claims pc
      where
        (v.auth_user_id is not null and pc.auth_user_id = v.auth_user_id)
        or (
          nullif(trim(coalesce(v.email, '')), '') is not null
          and lower(pc.claimant_email) = lower(v.email)
        )
        or (
          nullif(regexp_replace(coalesce(v.mobile, ''), '\D', '', 'g'), '') is not null
          and regexp_replace(coalesce(pc.claimant_mobile, ''), '\D', '', 'g')
              = regexp_replace(coalesce(v.mobile, ''), '\D', '', 'g')
        )
    );

  get diagnostics blocked_count = row_count;
  return blocked_count;
end;
$$;
