-- Custody assignment for children of divorced/separated couples.
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
--
-- After a family is marked as divorced or separated, admins can record
-- which parent each child lives with via edit.html. Shown on person.html
-- next to each child in the relevant family's children list.

ALTER TABLE public.family_members
  ADD COLUMN IF NOT EXISTS custody_parent text
  CHECK (custody_parent IN ('father', 'mother', 'shared'));
