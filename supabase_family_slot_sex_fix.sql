-- Keep families.husband_uid / wife_uid in line with each spouse's sex (2026-11-09)
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
--
-- Father/Mother everywhere on the site (person.html, search results,
-- akt_parent_names, akt_advanced_search, Browse Tree) come from which SLOT a
-- spouse sits in on the family record (husband_uid = Father, wife_uid =
-- Mother), not from people.sex. Correcting someone's sex on their profile
-- used to leave that slot unchanged, so their children kept showing the
-- mother as Father and the father as Mother (real case: Fatima Saleem /
-- Nesar Ahmad Noorullah, parents of Abdullah and Daniya Nesar).
--
-- 1. akt__swap_family_slots(family) swaps the two spouses between the slots,
--    together with everything that is tied to a slot: the per-side marriage
--    numbers and the children's custody_parent ('father' <-> 'mother').
-- 2. A trigger on people.sex swaps a family's slots when, after the change,
--    BOTH spouses would sit in the slot matching their sex once swapped
--    (woman in husband slot + man or nobody in wife slot, or the mirror).
--    It never swaps a couple recorded as both male or both female; those
--    need a person's sex corrected first, after which the trigger fixes
--    the slots on its own.
-- 3. One-time fix for the families that were already reversed this way
--    (11 on 2026-11-09).

create or replace function public.akt__swap_family_slots(p_family_uid text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  update public.families
     set husband_uid          = wife_uid,
         wife_uid             = husband_uid,
         husband_marriage_seq = wife_marriage_seq,
         wife_marriage_seq    = husband_marriage_seq
   where uid = p_family_uid;

  update public.family_members
     set custody_parent = case custody_parent
                            when 'father' then 'mother'
                            when 'mother' then 'father'
                            else custody_parent
                          end
   where family_uid = p_family_uid
     and custody_parent in ('father', 'mother');
end;
$$;

revoke all on function public.akt__swap_family_slots(text) from public, anon, authenticated;

create or replace function public.akt__fix_family_slots_on_sex_change()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  f record;
begin
  for f in
    select fam.uid, fam.husband_uid, fam.wife_uid,
           case when fam.husband_uid = new.uid then new.sex else h.sex end as h_sex,
           case when fam.wife_uid    = new.uid then new.sex else w.sex end as w_sex
      from public.families fam
      left join public.people h on h.uid = fam.husband_uid
      left join public.people w on w.uid = fam.wife_uid
     where new.uid in (fam.husband_uid, fam.wife_uid)
  loop
    if (f.h_sex = 'F' and (f.wife_uid is null or f.w_sex = 'M'))
       or (f.w_sex = 'M' and (f.husband_uid is null or f.h_sex = 'F')) then
      perform public.akt__swap_family_slots(f.uid);
    end if;
  end loop;
  return null;
end;
$$;

revoke all on function public.akt__fix_family_slots_on_sex_change() from public, anon, authenticated;

drop trigger if exists people_sex_fix_family_slots on public.people;
create trigger people_sex_fix_family_slots
  after update of sex on public.people
  for each row
  when (old.sex is distinct from new.sex)
  execute function public.akt__fix_family_slots_on_sex_change();

-- One-time fix: families already reversed (same rule as the trigger).
do $$
declare
  r record;
begin
  for r in
    select fam.uid
      from public.families fam
      left join public.people h on h.uid = fam.husband_uid
      left join public.people w on w.uid = fam.wife_uid
     where (h.sex = 'F' and (fam.wife_uid is null or w.sex = 'M'))
        or (w.sex = 'M' and (fam.husband_uid is null or h.sex = 'F'))
  loop
    perform public.akt__swap_family_slots(r.uid);
  end loop;
end;
$$;
