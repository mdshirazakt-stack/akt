-- Marriage ordering / labeling ("1st wife", "2nd husband", etc.)
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
--
-- Part of the spouse-handling revamp: lets admins explicitly record which
-- numbered marriage a given family group represents for EACH side of the
-- couple (a husband's 2nd marriage may be his wife's 1st, etc).
--
-- husband_marriage_seq = which marriage this is for the husband_uid person
-- wife_marriage_seq    = which marriage this is for the wife_uid person
--
-- Both are nullable — when not set, the UI falls back to ordering by
-- marr_date (oldest = 1st), and if that's also missing, no ordinal is shown.
-- Admins can set/override these explicitly via the "Marriage details" editor
-- in edit.html (useful for retroactively labeling old GEDCOM data where the
-- marriage order is known but dates are missing/ambiguous).

ALTER TABLE public.families
  ADD COLUMN IF NOT EXISTS husband_marriage_seq smallint
  CHECK (husband_marriage_seq IS NULL OR husband_marriage_seq > 0);

ALTER TABLE public.families
  ADD COLUMN IF NOT EXISTS wife_marriage_seq smallint
  CHECK (wife_marriage_seq IS NULL OR wife_marriage_seq > 0);
