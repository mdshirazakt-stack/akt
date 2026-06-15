-- One-time diagnostic + cleanup for duplicate family groups.
-- Run this in the Supabase SQL Editor, ONE STEP AT A TIME (read the comments
-- before each step - steps 2 and 3 need values from the previous step).
--
-- Background: a "families" row can end up duplicated when a spouse/partner
-- group is created in edit.html for a husband+wife pair that already has a
-- families row, and then "Import <spouse>'s children" copies the same
-- children into both rows via family_members. This script finds such
-- duplicates and helps you safely remove the extra row.

-- ============================================================
-- STEP 1: Find husband/wife pairs that have more than one families row.
-- ============================================================
select husband_uid, wife_uid, count(*) as family_count, array_agg(uid) as family_uids
from public.families
where husband_uid is not null and wife_uid is not null
group by husband_uid, wife_uid
having count(*) > 1;


-- ============================================================
-- STEP 2: For a pair found above, inspect each row's details and the
-- children currently linked to it. Replace <HUSBAND_UID> / <WIFE_UID>
-- below with the values from Step 1.
-- ============================================================
select
  f.uid as family_uid,
  f.gedcom_id,
  f.raw_gedcom_id,
  f.marr_date,
  f.marr_place,
  f.marr_status,
  f.marr_notes,
  count(fm.person_uid) as children_count,
  array_agg(p.name order by fm.birth_order) as children_names
from public.families f
left join public.family_members fm on fm.family_uid = f.uid
left join public.people p on p.uid = fm.person_uid
where f.husband_uid = '<HUSBAND_UID>'
  and f.wife_uid = '<WIFE_UID>'
group by f.uid, f.gedcom_id, f.raw_gedcom_id, f.marr_date, f.marr_place, f.marr_status, f.marr_notes
order by f.uid;


-- ============================================================
-- STEP 3: Decide which row to KEEP (usually the one with a gedcom_id,
-- marriage details, or the one that originally held the children) and
-- which to REMOVE (the duplicate, typically the one created later via
-- "Add spouse/partner"). Replace <DUPLICATE_FAMILY_UID> below with the
-- family_uid of the row you want to remove, then run both deletes together.
-- ============================================================
delete from public.family_members where family_uid = '<DUPLICATE_FAMILY_UID>';
delete from public.families where uid = '<DUPLICATE_FAMILY_UID>';

-- After running Step 3, reload edit.html for the affected person - the
-- duplicate "Family N" card should disappear, and the remaining card should
-- still show all 3 children.
