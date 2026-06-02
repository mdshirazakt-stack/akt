-- RLS Emergency Fix for apnonkitalash.com
-- Run this in the Supabase SQL editor (fusairoeiabmqvsbxhfi.supabase.co)
-- Does NOT depend on akt_has_role() — uses direct visitors table checks.
-- After running, ALL tables will be blocked to unauthenticated requests.

-- ── HELPER: reusable visitor role check ──────────────────────────────────────
-- Returns true if the current auth.uid() belongs to an approved visitor
CREATE OR REPLACE FUNCTION public.akt_is_visitor()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.visitors v
    WHERE v.auth_user_id = auth.uid()
      AND coalesce(v.is_blocked, false) = false
      AND coalesce(v.access_status, 'approved') = 'approved'
  );
$$;

-- Returns true if the current auth.uid() belongs to a moderator or above
CREATE OR REPLACE FUNCTION public.akt_is_staff()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.visitors v
    WHERE v.auth_user_id = auth.uid()
      AND v.access_role IN ('moderator','admin','superadmin')
      AND coalesce(v.is_blocked, false) = false
  );
$$;

-- Returns true if the current auth.uid() belongs to an admin or superadmin
CREATE OR REPLACE FUNCTION public.akt_is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.visitors v
    WHERE v.auth_user_id = auth.uid()
      AND v.access_role IN ('admin','superadmin')
      AND coalesce(v.is_blocked, false) = false
  );
$$;

GRANT EXECUTE ON FUNCTION public.akt_is_visitor() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.akt_is_staff()   TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.akt_is_admin()   TO anon, authenticated;

-- ── ENABLE RLS ON ALL TABLES ─────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.people                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.families                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.family_members              ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.gedcom_uploads              ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.visitors                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.visitor_consent_records     ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.activity_logs               ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.staff_activity_logs         ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.correction_requests         ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.suggestions                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.find_requests               ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.profile_claims              ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.role_applications           ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.signup_events               ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.person_profile_overrides    ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.relationship_overrides      ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.person_identity_groups      ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.person_identity_members     ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.canonical_family_groups     ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.canonical_family_children   ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.forum_categories            ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.forum_threads               ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.forum_posts                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.forum_flags                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.admin_config                ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.ads                         ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.ad_impressions              ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.ad_inquiries                ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_notifications          ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.family_members              ENABLE ROW LEVEL SECURITY;

-- ── DROP ALL EXISTING POLICIES (clean slate) ──────────────────────────────────
DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- ── CORE ARCHIVE (people, families, family_members, gedcom_uploads) ───────────
CREATE POLICY "people_visitor_read" ON public.people
  FOR SELECT TO authenticated USING (public.akt_is_visitor());
CREATE POLICY "people_admin_write" ON public.people
  FOR ALL TO authenticated USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());

CREATE POLICY "families_visitor_read" ON public.families
  FOR SELECT TO authenticated USING (public.akt_is_visitor());
CREATE POLICY "families_admin_write" ON public.families
  FOR ALL TO authenticated USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());

CREATE POLICY "family_members_visitor_read" ON public.family_members
  FOR SELECT TO authenticated USING (public.akt_is_visitor());
CREATE POLICY "family_members_admin_write" ON public.family_members
  FOR ALL TO authenticated USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());

CREATE POLICY "gedcom_uploads_visitor_read" ON public.gedcom_uploads
  FOR SELECT TO authenticated USING (public.akt_is_visitor());
CREATE POLICY "gedcom_uploads_admin_write" ON public.gedcom_uploads
  FOR ALL TO authenticated USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());

-- ── VISITORS TABLE ────────────────────────────────────────────────────────────
CREATE POLICY "visitors_self_read" ON public.visitors
  FOR SELECT TO authenticated
  USING (auth_user_id = auth.uid() OR public.akt_is_admin());

CREATE POLICY "visitors_self_insert" ON public.visitors
  FOR INSERT TO authenticated
  WITH CHECK (auth_user_id = auth.uid());

CREATE POLICY "visitors_self_update" ON public.visitors
  FOR UPDATE TO authenticated
  USING (auth_user_id = auth.uid() OR public.akt_is_admin())
  WITH CHECK (auth_user_id = auth.uid() OR public.akt_is_admin());

-- ── ACTIVITY LOGS ─────────────────────────────────────────────────────────────
CREATE POLICY "activity_logs_visitor_insert" ON public.activity_logs
  FOR INSERT TO authenticated WITH CHECK (public.akt_is_visitor());
CREATE POLICY "activity_logs_staff_read" ON public.activity_logs
  FOR SELECT TO authenticated USING (public.akt_is_staff());

CREATE POLICY "staff_activity_logs_staff_insert" ON public.staff_activity_logs
  FOR INSERT TO authenticated WITH CHECK (public.akt_is_staff());
CREATE POLICY "staff_activity_logs_staff_read" ON public.staff_activity_logs
  FOR SELECT TO authenticated USING (public.akt_is_staff());

-- ── SIGNUP EVENTS (public insert, admin read) ─────────────────────────────────
CREATE POLICY "signup_events_public_insert" ON public.signup_events
  FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "signup_events_admin_read" ON public.signup_events
  FOR SELECT TO authenticated USING (public.akt_is_admin());

-- ── PROFILE CLAIMS ────────────────────────────────────────────────────────────
CREATE POLICY "profile_claims_self_insert" ON public.profile_claims
  FOR INSERT TO authenticated WITH CHECK (auth_user_id = auth.uid());
CREATE POLICY "profile_claims_self_or_admin_read" ON public.profile_claims
  FOR SELECT TO authenticated
  USING (auth_user_id = auth.uid() OR public.akt_is_admin());
CREATE POLICY "profile_claims_admin_update" ON public.profile_claims
  FOR UPDATE TO authenticated
  USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());
CREATE POLICY "profile_claims_admin_delete" ON public.profile_claims
  FOR DELETE TO authenticated USING (public.akt_is_admin());

-- ── CORRECTIONS / SUGGESTIONS / FIND REQUESTS ────────────────────────────────
CREATE POLICY "corrections_visitor_insert" ON public.correction_requests
  FOR INSERT TO authenticated WITH CHECK (public.akt_is_visitor());
CREATE POLICY "corrections_staff_read" ON public.correction_requests
  FOR SELECT TO authenticated USING (public.akt_is_staff());
CREATE POLICY "corrections_staff_update" ON public.correction_requests
  FOR UPDATE TO authenticated
  USING (public.akt_is_staff()) WITH CHECK (public.akt_is_staff());

CREATE POLICY "suggestions_visitor_insert" ON public.suggestions
  FOR INSERT TO authenticated WITH CHECK (public.akt_is_visitor());
CREATE POLICY "suggestions_staff_read" ON public.suggestions
  FOR SELECT TO authenticated USING (public.akt_is_staff());
CREATE POLICY "suggestions_staff_update" ON public.suggestions
  FOR UPDATE TO authenticated
  USING (public.akt_is_staff()) WITH CHECK (public.akt_is_staff());

CREATE POLICY "find_requests_visitor_insert" ON public.find_requests
  FOR INSERT TO authenticated WITH CHECK (public.akt_is_visitor());
CREATE POLICY "find_requests_staff_read" ON public.find_requests
  FOR SELECT TO authenticated USING (public.akt_is_staff());
CREATE POLICY "find_requests_staff_update" ON public.find_requests
  FOR UPDATE TO authenticated
  USING (public.akt_is_staff()) WITH CHECK (public.akt_is_staff());

-- ── ROLE APPLICATIONS ─────────────────────────────────────────────────────────
CREATE POLICY "role_apps_visitor_insert" ON public.role_applications
  FOR INSERT TO authenticated WITH CHECK (public.akt_is_visitor());
CREATE POLICY "role_apps_self_or_admin_read" ON public.role_applications
  FOR SELECT TO authenticated
  USING (auth_user_id = auth.uid() OR public.akt_is_admin());
CREATE POLICY "role_apps_admin_update" ON public.role_applications
  FOR UPDATE TO authenticated
  USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());

-- ── PROFILE OVERRIDES & RELATIONSHIP TABLES ───────────────────────────────────
CREATE POLICY "overrides_staff_all" ON public.person_profile_overrides
  FOR ALL TO authenticated
  USING (public.akt_is_staff()) WITH CHECK (public.akt_is_staff());

CREATE POLICY "rel_overrides_visitor_read" ON public.relationship_overrides
  FOR SELECT TO authenticated USING (public.akt_is_visitor());
CREATE POLICY "rel_overrides_admin_write" ON public.relationship_overrides
  FOR ALL TO authenticated
  USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());

CREATE POLICY "identity_groups_admin" ON public.person_identity_groups
  FOR ALL TO authenticated
  USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());
CREATE POLICY "identity_members_admin" ON public.person_identity_members
  FOR ALL TO authenticated
  USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());

CREATE POLICY "cfg_visitor_read" ON public.canonical_family_groups
  FOR SELECT TO authenticated USING (public.akt_is_visitor());
CREATE POLICY "cfg_admin_write" ON public.canonical_family_groups
  FOR ALL TO authenticated
  USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());

CREATE POLICY "cfc_visitor_read" ON public.canonical_family_children
  FOR SELECT TO authenticated USING (public.akt_is_visitor());
CREATE POLICY "cfc_admin_write" ON public.canonical_family_children
  FOR ALL TO authenticated
  USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());

-- ── FORUM ─────────────────────────────────────────────────────────────────────
CREATE POLICY "forum_cats_visitor_read" ON public.forum_categories
  FOR SELECT TO authenticated USING (public.akt_is_visitor());

CREATE POLICY "forum_threads_read" ON public.forum_threads
  FOR SELECT TO authenticated
  USING (status = 'published' OR public.akt_is_staff());
CREATE POLICY "forum_threads_visitor_insert" ON public.forum_threads
  FOR INSERT TO authenticated WITH CHECK (public.akt_is_visitor() AND status = 'pending');
CREATE POLICY "forum_threads_staff_update" ON public.forum_threads
  FOR UPDATE TO authenticated
  USING (public.akt_is_staff()) WITH CHECK (public.akt_is_staff());

CREATE POLICY "forum_posts_read" ON public.forum_posts
  FOR SELECT TO authenticated
  USING (status = 'published' OR public.akt_is_staff());
CREATE POLICY "forum_posts_visitor_insert" ON public.forum_posts
  FOR INSERT TO authenticated WITH CHECK (public.akt_is_visitor() AND status = 'pending');
CREATE POLICY "forum_posts_staff_update" ON public.forum_posts
  FOR UPDATE TO authenticated
  USING (public.akt_is_staff()) WITH CHECK (public.akt_is_staff());

CREATE POLICY "forum_flags_visitor_insert" ON public.forum_flags
  FOR INSERT TO authenticated WITH CHECK (public.akt_is_visitor());
CREATE POLICY "forum_flags_staff_read" ON public.forum_flags
  FOR SELECT TO authenticated USING (public.akt_is_staff());
CREATE POLICY "forum_flags_staff_update" ON public.forum_flags
  FOR UPDATE TO authenticated
  USING (public.akt_is_staff()) WITH CHECK (public.akt_is_staff());

-- ── ADMIN CONFIG ──────────────────────────────────────────────────────────────
CREATE POLICY "admin_config_admin_only" ON public.admin_config
  FOR ALL TO authenticated
  USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());

-- ── ADS SYSTEM ────────────────────────────────────────────────────────────────
CREATE POLICY "ads_admin_all" ON public.ads
  FOR ALL TO authenticated
  USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());
CREATE POLICY "ads_visitor_read_active" ON public.ads
  FOR SELECT TO authenticated USING (status = 'active' AND public.akt_is_visitor());

CREATE POLICY "ad_impressions_admin_read" ON public.ad_impressions
  FOR SELECT TO authenticated USING (public.akt_is_admin());
CREATE POLICY "ad_impressions_self_insert" ON public.ad_impressions
  FOR INSERT TO authenticated
  WITH CHECK (visitor_id IN (SELECT id FROM public.visitors WHERE auth_user_id = auth.uid()));
CREATE POLICY "ad_impressions_self_update" ON public.ad_impressions
  FOR UPDATE TO authenticated
  USING (visitor_id IN (SELECT id FROM public.visitors WHERE auth_user_id = auth.uid()))
  WITH CHECK (true);

CREATE POLICY "ad_inquiries_public_insert" ON public.ad_inquiries
  FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "ad_inquiries_admin_read" ON public.ad_inquiries
  FOR SELECT TO authenticated USING (public.akt_is_admin());
CREATE POLICY "ad_inquiries_admin_update" ON public.ad_inquiries
  FOR UPDATE TO authenticated
  USING (public.akt_is_admin()) WITH CHECK (true);

-- ── USER NOTIFICATIONS ────────────────────────────────────────────────────────
CREATE POLICY "notif_admin_insert" ON public.user_notifications
  FOR INSERT TO authenticated WITH CHECK (public.akt_is_admin());
CREATE POLICY "notif_admin_read" ON public.user_notifications
  FOR SELECT TO authenticated USING (public.akt_is_admin());
CREATE POLICY "notif_self_read" ON public.user_notifications
  FOR SELECT TO authenticated
  USING (
    recipient_auth_uid = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.visitors v WHERE v.auth_user_id = auth.uid()
        AND (lower(v.email) = lower(recipient_email)
          OR regexp_replace(v.mobile,'[^0-9]','','g') = regexp_replace(recipient_mobile,'[^0-9]','','g'))
    )
  );
CREATE POLICY "notif_self_update" ON public.user_notifications
  FOR UPDATE TO authenticated
  USING (
    recipient_auth_uid = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.visitors v WHERE v.auth_user_id = auth.uid()
        AND (lower(v.email) = lower(recipient_email)
          OR regexp_replace(v.mobile,'[^0-9]','','g') = regexp_replace(recipient_mobile,'[^0-9]','','g'))
    )
  ) WITH CHECK (true);

-- ── VISITOR CONSENT ───────────────────────────────────────────────────────────
CREATE POLICY "consent_self_insert" ON public.visitor_consent_records
  FOR INSERT TO authenticated WITH CHECK (auth_user_id = auth.uid());
CREATE POLICY "consent_self_or_admin_read" ON public.visitor_consent_records
  FOR SELECT TO authenticated
  USING (auth_user_id = auth.uid() OR public.akt_is_admin());
