-- Family connections between two people (2026-11-09)
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
--
-- akt_connection_paths(from, to, max, limit) lists the closest DIFFERENT
-- routes between two people, best first. It walks UP from each of them
-- through BOTH parents, at most p_max generations (1..8), and joins the two
-- climbs where they meet at a shared ancestor. One marriage may be used at
-- either end, never both, which covers in-laws (a brother's wife, a wife's
-- brother, a son's wife, ...).
--
-- Ranking: the fewest steps first (a marriage counts as one step, so a
-- brother's wife comes before a 9-step blood link to the same person), then
-- blood before in-law at equal length, then the route running through the
-- fewest women (male links over female links when both exist), then the
-- father's side.
--
-- What counts as a different route:
--   * a route may not pass through the same person twice (no going up to a
--     great-grandfather and back down through the grandfather already used);
--   * routes that differ only in meeting at the husband or the wife of the
--     same couple (via father vs via mother of full siblings) count once.
--
-- Each route is jsonb:
--   up, down       generations from `from` up to the shared ancestor, and
--                  from there down to `to` (or to `to`'s spouse)
--   from_spouse    true when the route starts through `from`'s spouse
--   to_spouse      true when `to` is the spouse of the blood relative reached
--   first_father   true when the first step up from `from` (or their spouse)
--                  is through the father: paternal side
--   path           [{uid, name, sex}] from `from` to `to`, in order
--
-- akt_connection_path(from, to, max) is the single best route (or NULL), used
-- by the "How am I connected to this person?" bar.

drop function if exists public.akt_connection_paths(text, text, int, int);

create or replace function public.akt_connection_paths(p_from text, p_to text, p_max int default 7, p_limit int default 5)
returns jsonb
language plpgsql
stable
security invoker
set search_path to 'public'
as $$
declare
  m int := least(greatest(coalesce(p_max, 7), 1), 8);
  lim int := least(greatest(coalesce(p_limit, 5), 1), 10);
  cand record;
  uids text[];
  dedupe_key text;
  seen text[] := '{}';
  steps jsonb;
  routes jsonb := '[]'::jsonb;
begin
  if p_from is null or p_to is null or p_from = p_to then
    return routes;
  end if;

  for cand in
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
    up_a(via_spouse, uid, depth, path, first_father, female_links) as (
      select via_spouse, s, 0, array[s], null::boolean, 0 from starts_a
      union all
      select u.via_spouse, pe.parent, u.depth + 1, u.path || pe.parent, coalesce(u.first_father, pe.is_father),
             u.female_links + case when pe.is_father then 0 else 1 end
        from up_a u join parent_edge pe on pe.child = u.uid
       where u.depth < m and not pe.parent = any (u.path)
    ),
    up_b(via_spouse, uid, depth, path, female_links) as (
      select via_spouse, s, 0, array[s], 0 from starts_b
      union all
      select u.via_spouse, pe.parent, u.depth + 1, u.path || pe.parent,
             u.female_links + case when pe.is_father then 0 else 1 end
        from up_b u join parent_edge pe on pe.child = u.uid
       where u.depth < m and not pe.parent = any (u.path)
    )
    select a.via_spouse as from_spouse, b.via_spouse as to_spouse,
           a.depth as up, b.depth as down, a.path as a_path, b.path as b_path,
           a.first_father
      from up_a a
      join up_b b on b.uid = a.uid
     where not (a.via_spouse and b.via_spouse)
       -- the two climbs may only share the meeting ancestor itself
       and not (a.path[1:a.depth] && b.path)
       and not (b.path[1:b.depth] && a.path)
       and not (a.via_spouse and p_from = any (b.path))
       and not (b.via_spouse and p_to = any (a.path))
     order by a.depth + b.depth + a.via_spouse::int + b.via_spouse::int,
              (a.via_spouse::int + b.via_spouse::int),
              a.female_links + b.female_links,
              a.first_father desc nulls last,
              a.depth
     limit 400
  loop
    -- from [-> from's spouse] -> ancestors ... meeting ancestor ... -> descendants [-> to]
    uids := case when cand.from_spouse then array[p_from] else '{}'::text[] end
         || cand.a_path
         || coalesce((select array_agg(x order by i desc)
                        from unnest(cand.b_path) with ordinality t(x, i)
                       where i < array_length(cand.b_path, 1)), '{}'::text[])
         || case when cand.to_spouse then array[p_to] else '{}'::text[] end;

    -- same route except for which spouse of a couple it meets at: count once
    dedupe_key := cand.up || ':' || cand.down || ':' || array_to_string(
      uids[1:(case when cand.from_spouse then 1 else 0 end) + cand.up]
      || uids[(case when cand.from_spouse then 1 else 0 end) + cand.up + 2:], '>');
    continue when dedupe_key = any (seen);
    seen := seen || dedupe_key;

    select jsonb_agg(jsonb_build_object('uid', u.uid, 'name', p.name, 'sex', p.sex) order by u.i)
      into steps
      from unnest(uids) with ordinality u(uid, i)
      left join people p on p.uid = u.uid;

    routes := routes || jsonb_build_array(jsonb_build_object(
      'up', cand.up, 'down', cand.down,
      'from_spouse', cand.from_spouse, 'to_spouse', cand.to_spouse,
      'first_father', coalesce(cand.first_father, true),
      'path', steps));
    exit when jsonb_array_length(routes) >= lim;
  end loop;

  return routes;
end;
$$;

create or replace function public.akt_connection_path(p_from text, p_to text, p_max int default 4)
returns jsonb
language sql
stable
security invoker
set search_path to 'public'
as $$
  select public.akt_connection_paths(p_from, p_to, p_max, 1) -> 0;
$$;

revoke all on function public.akt_connection_paths(text, text, int, int) from public, anon;
grant execute on function public.akt_connection_paths(text, text, int, int) to authenticated;
revoke all on function public.akt_connection_path(text, text, int) from public, anon;
grant execute on function public.akt_connection_path(text, text, int) to authenticated;
