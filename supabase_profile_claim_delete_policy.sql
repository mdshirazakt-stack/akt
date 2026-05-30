-- Missing DELETE policy for profile_claims
-- Without this, admin delete calls silently delete 0 rows (RLS blocks them)
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)

CREATE POLICY "profile_claims_admin_delete"
ON public.profile_claims
FOR DELETE
TO authenticated
USING (public.akt_has_role('admin'));
