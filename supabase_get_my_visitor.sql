-- Safe visitor lookup bypassing RLS — needed after RLS fix.
-- findVisitorForUser() in auth-flow.js relies on reading the visitors
-- table to check if a user is blocked/approved. After RLS, users whose
-- auth_user_id is null can't read their own record, so they appear as
-- new users and bypass blocking.
-- This SECURITY DEFINER function does the lookup as the DB owner,
-- returning only the calling user's own record (matched by auth.uid()
-- OR by email from auth.users).
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)

CREATE OR REPLACE FUNCTION public.get_my_visitor()
RETURNS json LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT row_to_json(v)
  FROM public.visitors v
  WHERE v.auth_user_id = auth.uid()
     OR lower(v.email) = lower(
          coalesce((SELECT email FROM auth.users WHERE id = auth.uid() LIMIT 1), '')
        )
  ORDER BY v.last_seen DESC NULLS LAST
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_visitor() TO anon, authenticated;
