-- "How am I connected to this person?" (2026-11-09)
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
--
-- akt_connection_path(from, to, max) finds the closest family connection
-- between two people. It walks UP from each of them through BOTH parents
-- (father and mother), at most p_max generations (1..8; the page asks for 4,
-- then 8 if the person wants to search further), and picks the nearest
-- shared ancestor. One marriage may be used at either end, never both, which
-- covers in-laws: a brother's wife (sister-in-law), a wife's brother, a son's
-- wife, and so on. Blood connections are preferred over in-law ones, then the
-- shortest path, then the father's side.
--
-- Returns NULL when nothing is found, else jsonb:
--   up, down       generations from `from` up to the shared ancestor, and
--                  from there down to `to` (or to `to`'s spouse)
--   from_spouse    true when the path starts through `from`'s spouse
--   to_spouse      true when `to` is the spouse of the blood relative reached
--   first_father   true when the first step up from `from` (or from their
--                  spouse) is through the father: paternal side
--   path           [{uid, name, sex}] from `from` to `to`, in order

create or replace function public.akt_connection_path(p_from text, p_to text, p_max int default 4)
returns jsonb
language plpgsql
stable
security invoker
set search_path to 'public'
as $$
declare
  m int := least(greatest(coalesce(p_max, 4), 1), 8);
  best record;
  uids text[];
  result jsonb;
begin
  if p_from is null or p_to is null or p_from = p_to then
    return null;
  end if;

  with recursive
  parent_edge as (
    select fm.person_uid as child, f.husband_uid as parent, true as is_father
      from family_members fm join families f on f.uid = fm.family_uid
     where fm.role = 'child' and f.husband_uid is not null
    union all
    select fm.person_uid, f.wife_uid, false
      from family_members fm join families f on f.uid = fm.family_uid
     where fm.role = 'child' and f.wife_uid is not null
  ),
  starts_a as (
    select p_from as s, false as via_spouse
    union
    select case when f.husband_uid = p_from then f.wife_uid else f.husband_uid end, true
      from families f
     where p_from in (f.husband_uid, f.wife_uid)
       and f.husband_uid is not null and f.wife_uid is not null
  ),
  starts_b as (
    select p_to as s, false as via_spouse
    union
    select case when f.husband_uid = p_to then f.wife_uid else f.husband_uid end, true
      from families f
     where p_to in (f.husband_uid, f.wife_uid)
       and f.husband_uid is not null and f.wife_uid is not null
  ),
  up_a(via_spouse, uid, depth, path, first_father) as (
    select via_spouse, s, 0, array[s], null::boolean from starts_a
    union all
    select u.via_spouse, pe.parent, u.depth + 1, u.path || pe.parent, coalesce(u.first_father, pe.is_father)
      from up_a u join parent_edge pe on pe.child = u.uid
     where u.depth < m and not pe.parent = any (u.path)
  ),
  up_b(via_spouse, uid, depth, path) as (
    select via_spouse, s, 0, array[s] from starts_b
    union all
    select u.via_spouse, pe.parent, u.depth + 1, u.path || pe.parent
      from up_b u join parent_edge pe on pe.child = u.uid
     where u.depth < m and not pe.parent = any (u.path)
  )
  select a.via_spouse as from_spouse, b.via_spouse as to_spouse,
         a.depth as up, b.depth as down, a.path as a_path, b.path as b_path,
         a.first_father
    into best
    from up_a a
    join up_b b on b.uid = a.uid
   where not (a.via_spouse and b.via_spouse)
   order by (a.via_spouse::int + b.via_spouse::int),
            a.depth + b.depth,
            a.first_father desc nulls last,
            a.depth
   limit 1;

  if not found then
    return null;
  end if;

  -- from [-> from's spouse] -> ancestors ... shared ancestor ... -> descendants [-> to]
  uids := case when best.from_spouse then array[p_from] else '{}'::text[] end
       || best.a_path
       || coalesce((select array_agg(x order by i desc)
                      from unnest(best.b_path) with ordinality t(x, i)
                     where i < array_length(best.b_path, 1)), '{}'::text[])
       || case when best.to_spouse then array[p_to] else '{}'::text[] end;

  select jsonb_agg(jsonb_build_object('uid', u.uid, 'name', p.name, 'sex', p.sex) order by u.i)
    into result
    from unnest(uids) with ordinality u(uid, i)
    left join people p on p.uid = u.uid;

  return jsonb_build_object(
    'up', best.up, 'down', best.down,
    'from_spouse', best.from_spouse, 'to_spouse', best.to_spouse,
    'first_father', coalesce(best.first_father, true),
    'path', result);
end;
$$;

revoke all on function public.akt_connection_path(text, text, int) from public, anon;
grant execute on function public.akt_connection_path(text, text, int) to authenticated;
