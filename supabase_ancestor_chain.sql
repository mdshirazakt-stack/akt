-- Ancestor chain for the profile page (2026-11-09)
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
--
-- akt_ancestor_chain(uid, max) walks up from a person one generation at a
-- time and returns that line of ancestors: depth 1 = parent, 2 = grandparent,
-- and so on, up to p_max (capped at 50). At each step it takes the FATHER
-- (families.husband_uid); only when no father is recorded does it take the
-- MOTHER (wife_uid). When a person sits in more than one parent family it
-- uses the same one the profile page shows (lowest birth_order, then family
-- uid). The walk stops at a repeated person, so a data loop can't run forever.
--
-- The row at the last depth also says whether that ancestor has a parent of
-- their own (has_more), so the page can offer "show more generations".

create or replace function public.akt_ancestor_chain(p_uid text, p_max int default 7)
returns table (depth int, uid text, name text, sex text, death_flag text, has_more boolean)
language sql
stable
security invoker
set search_path to 'public'
as $$
  with recursive chain(depth, uid, path) as (
    select 0, p_uid, array[p_uid]
    union all
    select c.depth + 1, nxt.parent_uid, c.path || nxt.parent_uid
      from chain c
      cross join lateral (
        select coalesce(f.husband_uid, f.wife_uid) as parent_uid
          from public.family_members fm
          join public.families f on f.uid = fm.family_uid
         where fm.person_uid = c.uid
           and fm.role = 'child'
           and coalesce(f.husband_uid, f.wife_uid) is not null
         order by fm.birth_order nulls last, fm.family_uid
         limit 1
      ) nxt
     where c.depth < least(greatest(coalesce(p_max, 7), 1), 50) + 1
       and not nxt.parent_uid = any (c.path)
  )
  select c.depth, c.uid, p.name, p.sex, p.death_flag::text,
         exists (select 1 from chain c2 where c2.depth = c.depth + 1)
    from chain c
    left join public.people p on p.uid = c.uid
   where c.depth between 1 and least(greatest(coalesce(p_max, 7), 1), 50)
   order by c.depth;
$$;

revoke all on function public.akt_ancestor_chain(text, int) from public, anon;
grant execute on function public.akt_ancestor_chain(text, int) to authenticated;
