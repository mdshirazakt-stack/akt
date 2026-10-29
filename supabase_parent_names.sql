-- Parent names for a page of search results (2026-10-29) — used by index.html's
-- main search / home-page table to show Father and Mother columns.
--
-- Takes the uids of the rows on the current page (max 100) and returns each
-- one's father and mother from their parent family (role 'child' in
-- family_members → families.husband_uid / wife_uid). Same lookup as the
-- Father/Mother columns of akt_advanced_search(). A person with no parent
-- family recorded simply gets no row.
--
-- SECURITY INVOKER: runs with the caller's own rights, so the existing
-- people/families/family_members RLS (approved visitors only) still decides
-- who can read these names.

create or replace function public.akt_parent_names(p_uids text[])
returns table (uid text, father_name text, mother_name text)
language sql
stable
security invoker
set search_path to 'public'
as $$
  select fm.person_uid,
         (array_agg(fa.name order by fa.name) filter (where fa.name is not null))[1],
         (array_agg(mo.name order by mo.name) filter (where mo.name is not null))[1]
    from public.family_members fm
    join public.families fp on fp.uid = fm.family_uid
    left join public.people fa on fa.uid = fp.husband_uid
    left join public.people mo on mo.uid = fp.wife_uid
   where fm.role = 'child'
     and fm.person_uid = any (p_uids[1:100])
   group by fm.person_uid;
$$;

revoke all on function public.akt_parent_names(text[]) from public, anon;
grant execute on function public.akt_parent_names(text[]) to authenticated;
