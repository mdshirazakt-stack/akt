-- Marriage/family merge metadata for Apno Ki Talash.
-- Run this in the AKT Supabase project:
-- https://fusairoeiabmqvsbxhfi.supabase.co
--
-- These fields keep the raw GEDCOM import intact while allowing admins to
-- mark reviewed spouse-child groupings as canonical for future GEDCOM export.

alter table public.canonical_family_groups
  add column if not exists relationship_status text default 'married',
  add column if not exists marriage_date_text text,
  add column if not exists divorce_date_text text,
  add column if not exists merge_status text default 'reviewed',
  add column if not exists merged_at timestamptz,
  add column if not exists merged_by text,
  add column if not exists merge_notes text;

update public.canonical_family_groups
set merge_status = coalesce(merge_status, 'reviewed'),
    relationship_status = coalesce(relationship_status, 'married')
where merge_status is null
   or relationship_status is null;

create index if not exists idx_canonical_family_groups_merge_status
  on public.canonical_family_groups(merge_status);
