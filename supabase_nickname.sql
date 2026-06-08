-- Nickname / "Also Known As" field
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
--
-- Adds a free-text `nickname` column to the people table so a person's
-- commonly-used "also known as" name can be recorded and shown alongside
-- their formal name.
--
-- Surfaced in:
--   - person.html   — shown in a dedicated "Also Known As" card on the profile
--   - index.html    — included in the main search (name/places/nickname)
--   - edit.html     — editable by moderators/admins (add the input there too)
--
-- No RLS changes needed: the existing `people` RLS policies
-- (people_visitor_read / people_admin_write from supabase_rls_fix.sql)
-- already cover all columns via SELECT * / explicit column lists.

ALTER TABLE public.people
  ADD COLUMN IF NOT EXISTS nickname text;

COMMENT ON COLUMN public.people.nickname IS
  'Optional "also known as" / commonly-used nickname, shown on the public profile and searchable.';
