-- Community role badge column
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
-- Adds community_role to people table for moderator / admin / superadmin badges.
-- Admin assigns roles from admin.html > Badges tab.
-- Badges are shown on person.html profiles and in archive search results.

ALTER TABLE public.people
  ADD COLUMN IF NOT EXISTS community_role text
  CHECK (community_role IN ('moderator', 'admin', 'superadmin'));
