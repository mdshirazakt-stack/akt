-- Superadmin-only delete policies for visitors and profile_claims.
--
-- WHY THIS FILE EXISTS:
--   1. profile_claims_admin_delete (created in supabase_profile_claim_delete_policy.sql)
--      used akt_has_role('admin') which is broken — deletes silently returned 0 rows.
--   2. Both the visitors and profile_claims DELETE policies previously allowed
--      any admin role. Deletion is a destructive, irreversible action — restricting
--      it to superadmin at the DB layer matches the JS-level guard in admin.html.
--
-- ORDER OF OPERATIONS:
--   Run this file AFTER supabase_rls_fix.sql. It patches the two DELETE policies
--   created by that file.
--
-- RUN IN: Supabase SQL Editor

-- ── 1. New helper function: akt_is_superadmin() ──────────────────────────────
CREATE OR REPLACE FUNCTION public.akt_is_superadmin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.visitors v
    WHERE v.auth_user_id = auth.uid()
      AND v.access_role = 'superadmin'
      AND coalesce(v.is_blocked, false) = false
  );
$$;

GRANT EXECUTE ON FUNCTION public.akt_is_superadmin() TO anon, authenticated;

-- ── 2. profile_claims — replace with superadmin-only DELETE ─────────────────
-- Drop both the rls_fix version and the old broken version (whichever exists)
DROP POLICY IF EXISTS "profile_claims_admin_delete"      ON public.profile_claims;
DROP POLICY IF EXISTS "profile_claims_superadmin_delete" ON public.profile_claims;

CREATE POLICY "profile_claims_superadmin_delete"
  ON public.profile_claims
  FOR DELETE TO authenticated
  USING (public.akt_is_superadmin());

-- ── 3. visitors — replace with superadmin-only DELETE ────────────────────────
-- Deletion of visitor records is irreversible; restrict to superadmin only.
-- (The existing policy "visitors_admin_delete" allows all admins — too broad.)
DROP POLICY IF EXISTS "visitors_admin_delete"      ON public.visitors;
DROP POLICY IF EXISTS "visitors_superadmin_delete" ON public.visitors;

CREATE POLICY "visitors_superadmin_delete"
  ON public.visitors
  FOR DELETE TO authenticated
  USING (public.akt_is_superadmin());

-- ── Verify ────────────────────────────────────────────────────────────────────
-- Run this SELECT to confirm the two policies are in place:
--
-- SELECT policyname, tablename, cmd, qual
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN ('visitors', 'profile_claims')
--   AND cmd = 'DELETE'
-- ORDER BY tablename;
--
-- Expected rows:
--   profile_claims | profile_claims_superadmin_delete | DELETE | akt_is_superadmin()
--   visitors       | visitors_superadmin_delete        | DELETE | akt_is_superadmin()
