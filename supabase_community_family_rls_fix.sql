-- Fix: "RLS Disabled in Public" errors (Supabase Security Advisor) for
--   - public.community_family_submissions
--   - public.community_family_people
--   - public.community_family_relationships
--
-- WHY THIS HAPPENED:
--   These 3 tables are created by supabase_relationship_mvp.sql, which does
--   NOT enable RLS or add policies. supabase_security_hardening.sql *does*
--   include RLS-enable + staff-only policy statements for these tables, but
--   the Security Advisor still flags them — so either that part never ran,
--   or the tables were (re)created after hardening last ran.
--
-- WHAT THIS DOES:
--   Enables RLS on all 3 tables and restricts ALL access (select/insert/
--   update/delete) to admins/superadmins via akt_is_admin() — matching how
--   these tables are actually used (admin.html "Family Builder" tab only;
--   no visitor-facing reads or writes anywhere in index.html/person.html).
--
-- RUN IN: Supabase SQL Editor (fusairoeiabmqvsbxhfi.supabase.co)

-- ── 0. Ensure akt_is_admin() exists (idempotent — same definition as
--      supabase_rls_fix.sql). Safe to re-run even if already present. ──────
CREATE OR REPLACE FUNCTION public.akt_is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.visitors v
    WHERE v.auth_user_id = auth.uid()
      AND v.access_role IN ('admin','superadmin')
      AND coalesce(v.is_blocked, false) = false
  );
$$;

GRANT EXECUTE ON FUNCTION public.akt_is_admin() TO anon, authenticated;

-- ── 1. Enable RLS ─────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.community_family_submissions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.community_family_people        ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.community_family_relationships ENABLE ROW LEVEL SECURITY;

-- ── 2. Drop any stale/partial policies, then add staff-only policies ──────
DROP POLICY IF EXISTS "community_family_submissions_staff_only"   ON public.community_family_submissions;
DROP POLICY IF EXISTS "community_family_people_staff_only"        ON public.community_family_people;
DROP POLICY IF EXISTS "community_family_relationships_staff_only" ON public.community_family_relationships;

CREATE POLICY "community_family_submissions_staff_only"
  ON public.community_family_submissions
  FOR ALL TO authenticated
  USING (public.akt_is_admin())
  WITH CHECK (public.akt_is_admin());

CREATE POLICY "community_family_people_staff_only"
  ON public.community_family_people
  FOR ALL TO authenticated
  USING (public.akt_is_admin())
  WITH CHECK (public.akt_is_admin());

CREATE POLICY "community_family_relationships_staff_only"
  ON public.community_family_relationships
  FOR ALL TO authenticated
  USING (public.akt_is_admin())
  WITH CHECK (public.akt_is_admin());

-- ── Verify ──────────────────────────────────────────────────────────────────
-- 1. Confirm RLS is enabled:
--    SELECT relname, relrowsecurity
--    FROM pg_class
--    WHERE relname IN ('community_family_submissions','community_family_people','community_family_relationships');
--    -> relrowsecurity should be 't' for all three.
--
-- 2. Confirm policies exist:
--    SELECT policyname, tablename, cmd, qual
--    FROM pg_policies
--    WHERE schemaname = 'public'
--      AND tablename IN ('community_family_submissions','community_family_people','community_family_relationships');
--
-- 3. In Supabase Dashboard -> Advisors -> Security Advisor, click "Refresh" —
--    the 3 "RLS Disabled in Public" errors should disappear.
