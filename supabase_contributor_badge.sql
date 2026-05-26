-- Contributor badge
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
-- Adds is_contributor flag to people table.
-- Admin grants/revokes the badge from admin.html > Contributors tab.
-- The badge is shown on the person's public profile in person.html.

ALTER TABLE public.people
  ADD COLUMN IF NOT EXISTS is_contributor boolean DEFAULT false;
