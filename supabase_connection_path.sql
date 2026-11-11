-- Family connections between two people (2026-11-10, v2: graph search)
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
--
-- akt_connection_paths(from, to, max, limit) lists the closest DIFFERENT
-- routes between two people, best first. It treats the archive as a family
-- graph (child -> parent "up", parent -> child "down", husband <-> wife
-- "spouse") and searches outward from BOTH people at once, at most p_max
-- steps from each side (1..8), keeping the best way to reach every person.
-- A route can therefore pass through marriages anywhere along it, e.g.
--   you -> your brother = his wife -> her father -> his sister
--   ("your brother's wife's aunt")
-- not only at its two ends (v1 could only use a marriage at an end).
--
-- Rules that keep routes meaningful:
--   * within a blood stretch a route goes up and then down, never down and
--     back up (that would be "your son's mother", which the marriage link
--     already covers); never two marriages in a row; at most 3 marriages;
--   * no person twice on a route, counting duplicate records linked in
--     person_identity_members as one person; the search also steps across
--     those links (a 'same' hop, free and never shown), so a line recorded
--     partly under one copy of a person and partly under another is found;
--   * a route may not come back DOWN through an ancestor of the starting
--     person (or of their spouse), nor go UP through an ancestor of the
--     target: that is a loop through their own line, not another relation;
--   * routes that differ only in meeting at the husband or the wife of the
--     same couple (via father vs via mother of full siblings) count once;
--   * no detour through a marriage that just swaps one parent for the other
--     (up to the mother, across to her husband = up to the father), also
--     when one of them is recorded under a duplicate (identity-linked) record;
--   * no route through someone descended from both ends (a couple's own
--     children are not a separate relation between the couple).
--
-- Ranking: fewest steps, where each marriage counts as two (so a blood link
-- beats an equally close in-law/step link), then fewest marriages, then fewest
-- women along the route (male links over female links when both exist), then
-- the father's side.
--
-- Each route is jsonb:
--   path   [{uid, name, sex}] from `from` to `to`
--   dirs   the step between each pair: 'up' | 'down' | 'spouse'
--   segmented  true when a marriage sits in the middle of the route
-- and, when the route has the classic shape [spouse] up* down* [spouse]:
--   up, down, from_spouse, to_spouse, first_father (paternal side)
--
-- akt_connection_path(from, to, max) is the single best route (or NULL).

drop function if exists public.akt_connection_paths(text, text, int, int);

create or replace function public.akt_connection_paths(p_from text, p_to text, p_max int default 7, p_limit int default 5)
returns jsonb
language plpgsql
volatile
security invoker
set search_path to 'public'
as $$
declare
  m int := least(greatest(coalesce(p_max, 7), 1), 8);
  lim int := least(greatest(coalesce(p_limit, 5), 1), 10);
  lvl int;
  s char(1);
  cand record;
  uids text[];
  v_dirs text[];
  canon text[];
  dedupe_key text;
  seen text[] := '{}';
  steps jsonb;
  routes jsonb := '[]'::jsonb;
  anc_from text[];
  anc_to text[];
  anc_from_sp text[];
  anc_to_sp text[];
  anc_from_d int[];
  anc_to_d int[];
  anc_from_sp_d int[];
  anc_to_sp_d int[];
  pos int;
  desc_both text[];
  bad boolean;
  k_i int;
  core text;
  fs boolean;
  ts boolean;
  n_up int;
  n_down int;
begin
  if p_from is null or p_to is null or p_from = p_to then
    return routes;
  end if;

  create temp table if not exists _cf_reach (
    side char(1), uid text, ph char(1), d int, path text[], dirs text[],
    marr int, fem int, father_first boolean, last text, wed boolean,
    primary key (side, uid, ph, wed)
  ) on commit drop;
  truncate _cf_reach;

  -- ph: 'u' = may still go up (arrived by start/up/spouse), 'd' = arrived going down
  -- wed: the way here already crossed a marriage. The best way to reach each
  -- person is kept separately for blood-only and for through-a-marriage, so a
  -- shorter in-law shortcut never hides a blood connection.
  insert into _cf_reach values
    ('a', p_from, 'u', 0, array[p_from], '{}', 0, 0, null, 'start', false),
    ('b', p_to,   'u', 0, array[p_to],   '{}', 0, 0, null, 'start', false);

  for lvl in 1..m loop
    foreach s in array array['a', 'b']::char(1)[] loop
      insert into _cf_reach
      select distinct on (x.uid, x.ph, x.wed) x.*
        from (
          -- up: to each parent (only while still allowed to go up)
          select r.side, par.uid, 'u'::char(1), lvl, r.path || par.uid, r.dirs || 'up'::text,
                 r.marr, r.fem + case when par.is_father then 0 else 1 end,
                 coalesce(r.father_first, par.is_father), 'up'::text, r.wed
            from _cf_reach r
            join family_members fm on fm.person_uid = r.uid and fm.role = 'child'
            join families f on f.uid = fm.family_uid
            cross join lateral (values (f.husband_uid, true), (f.wife_uid, false)) par(uid, is_father)
           where r.side = s and r.d = lvl - 1 and r.ph = 'u'
             and par.uid is not null and not par.uid = any (r.path)
          union all
          -- down: to each child
          select r.side, fm.person_uid, 'd'::char(1), lvl, r.path || fm.person_uid, r.dirs || 'down'::text,
                 r.marr, r.fem + case when c.sex = 'F' then 1 else 0 end,
                 r.father_first, 'down'::text, r.wed
            from _cf_reach r
            join families f on (f.husband_uid = r.uid or f.wife_uid = r.uid)
            join family_members fm on fm.family_uid = f.uid and fm.role = 'child'
            left join people c on c.uid = fm.person_uid
           where r.side = s and r.d = lvl - 1
             and not fm.person_uid = any (r.path)
          union all
          -- spouse (never two marriages in a row, at most 3 in all)
          select r.side, sp.uid, 'u'::char(1), lvl, r.path || sp.uid, r.dirs || 'spouse'::text,
                 r.marr + 1, r.fem + case when p2.sex = 'F' then 1 else 0 end,
                 r.father_first, 'spouse'::text, true
            from _cf_reach r
            join families f on (f.husband_uid = r.uid or f.wife_uid = r.uid)
            cross join lateral (select case when f.husband_uid = r.uid then f.wife_uid else f.husband_uid end as uid) sp
            left join people p2 on p2.uid = sp.uid
           where r.side = s and r.d = lvl - 1 and r.last <> 'spouse' and r.marr < 3
             and sp.uid is not null and not sp.uid = any (r.path)
          union all
          -- same person: hop to a duplicate record of this person (linked in
          -- person_identity_members), so a line recorded partly under one copy
          -- and partly under another is still followed. Not a real step: it
          -- keeps the direction and the last move, is never taken twice in a
          -- row, and is removed from the route before it is shown.
          select r.side, m2.person_uid, r.ph, lvl, r.path || m2.person_uid, r.dirs || 'same'::text,
                 r.marr, r.fem, r.father_first, r.last, r.wed
            from _cf_reach r
            join person_identity_members m1 on m1.person_uid = r.uid
            join person_identity_members m2 on m2.group_id = m1.group_id and m2.person_uid <> r.uid
           where r.side = s and r.d = lvl - 1
             and r.dirs[cardinality(r.dirs)] is distinct from 'same'
             and not m2.person_uid = any (r.path)
        ) x(side, uid, ph, d, path, dirs, marr, fem, father_first, last, wed)
       where not exists (select 1 from _cf_reach e where e.side = x.side and e.uid = x.uid and e.ph = x.ph and e.wed = x.wed)
       order by x.uid, x.ph, x.wed, x.marr, x.fem, x.father_first desc nulls last
      on conflict do nothing;
    end loop;
  end loop;

  -- ancestors of each end (or of their spouse): routes must not loop through them
  -- (the spouse's ancestors only count when the route starts / ends through
  --  that marriage)
  -- each with how many generations up it sits (its straight-climb distance)
  -- ('same' hops to a duplicate record are ignored: they are not a generation)
  select coalesce(array_agg(r.uid order by r.d), '{}'),
         coalesce(array_agg(cardinality(array_remove(r.dirs, 'same')) order by r.d), '{}')
    into anc_from, anc_from_d from _cf_reach r
   where r.side = 'a' and r.d > 0
     and array_to_string(array_remove(r.dirs, 'same'), ',') ~ '^up(,up)*$';
  select coalesce(array_agg(r.uid order by r.d), '{}'),
         coalesce(array_agg(cardinality(array_remove(r.dirs, 'same')) order by r.d), '{}')
    into anc_to, anc_to_d from _cf_reach r
   where r.side = 'b' and r.d > 0
     and array_to_string(array_remove(r.dirs, 'same'), ',') ~ '^up(,up)*$';
  select coalesce(array_agg(r.uid order by r.d), '{}'),
         coalesce(array_agg(cardinality(array_remove(r.dirs, 'same')) order by r.d), '{}')
    into anc_from_sp, anc_from_sp_d from _cf_reach r
   where r.side = 'a' and r.d > 1
     and array_to_string(array_remove(r.dirs, 'same'), ',') ~ '^spouse,up(,up)*$';
  select coalesce(array_agg(r.uid order by r.d), '{}'),
         coalesce(array_agg(cardinality(array_remove(r.dirs, 'same')) order by r.d), '{}')
    into anc_to_sp, anc_to_sp_d from _cf_reach r
   where r.side = 'b' and r.d > 1
     and array_to_string(array_remove(r.dirs, 'same'), ',') ~ '^spouse,up(,up)*$';

  -- people descended from BOTH ends (e.g. a couple's own children): a route
  -- through them is never a separate relation between the two
  select coalesce(array_agg(a.uid), '{}') into desc_both
    from _cf_reach a join _cf_reach b on b.uid = a.uid and b.side = 'b'
   where a.side = 'a' and a.d > 0 and b.d > 0
     and array_to_string(array_remove(a.dirs, 'same'), ',') ~ '^down(,down)*$'
     and array_to_string(array_remove(b.dirs, 'same'), ',') ~ '^down(,down)*$';

  for cand in
    -- every person along a route is a meeting point, so the same route shows up
    -- once per person on it: keep one copy of each full route before ranking
    select * from (
    select distinct on (full_path) *
      from (
        select a.path as a_path, a.dirs as a_dirs, b.path as b_path, b.dirs as b_dirs,
               a.father_first,
               a.d + b.d - cardinality(array_positions(a.dirs || b.dirs, 'same')) as total,
               cardinality(array_positions(a.dirs || b.dirs, 'same')) as sames,
               a.marr + b.marr as marr, a.fem + b.fem as fem,
               a.path || coalesce((select array_agg(x order by oi desc)
                                     from unnest(b.path) with ordinality t(x, oi)
                                    where oi < array_length(b.path, 1)), '{}'::text[]) as full_path
          from _cf_reach a
          join _cf_reach b on b.side = 'b' and b.uid = a.uid
         where a.side = 'a'
           and not (a.ph = 'd' and b.ph = 'd')               -- down then back up
           and not (a.last = 'spouse' and b.last = 'spouse') -- two marriages in a row
           and a.marr + b.marr <= 3
           and not (a.path[1:a.d] && b.path)
           and not (b.path[1:b.d] && a.path)
      ) c
     order by full_path, total, marr, fem, sames
    ) u
     order by total + marr, marr, fem, sames, father_first desc nulls last
     limit 1500
    loop
    -- full route: from ... meeting person ... to
    uids := cand.a_path
         || coalesce((select array_agg(x order by oi desc)
                        from unnest(cand.b_path) with ordinality t(x, oi)
                       where oi < array_length(cand.b_path, 1)), '{}'::text[]);
    v_dirs := cand.a_dirs
         || coalesce((select array_agg(case x when 'up' then 'down' when 'down' then 'up' else x end order by oi desc)
                        from unnest(cand.b_dirs) with ordinality t(x, oi)), '{}'::text[]);

    -- drop the duplicate-record hops: keep the record the route continues
    -- from (but always keep the two ends themselves)
    if 'same' = any (v_dirs) then
      select array_agg(t.x order by t.i) into uids
        from unnest(uids) with ordinality t(x, i)
       where not ((t.i > 1 and t.i <= cardinality(v_dirs) and v_dirs[t.i] = 'same')
                  or (t.i = 2 and v_dirs[1] = 'same' and cardinality(v_dirs) > 1));
      v_dirs := array_remove(v_dirs, 'same');
      continue when cardinality(v_dirs) = 0;
    end if;

    -- no looping back into either end's own line: reaching one of the start's
    -- ancestors any way other than the straight climb is a loop when it takes
    -- MORE steps than that climb (e.g. down through your own mother to your
    -- brother). Reaching the same ancestor in the same number of steps through
    -- another line is a genuine second connection (cousin marriages), so it
    -- stays. Same for the target's ancestors, counted from the target's end.
    bad := false;
    for k_i in 2 .. array_length(uids, 1) loop
      pos := array_position(anc_from, uids[k_i]);
      if pos is not null and k_i - 1 > anc_from_d[pos]
         and coalesce(array_to_string(v_dirs[1:k_i - 1], ','), '') !~ '^up(,up)*$' then
        bad := true; exit;
      end if;
      pos := array_position(anc_from_sp, uids[k_i]);
      if v_dirs[1] = 'spouse' and pos is not null and k_i - 1 > anc_from_sp_d[pos]
         and coalesce(array_to_string(v_dirs[2:k_i - 1], ','), '') !~ '^up(,up)*$' then
        bad := true; exit;
      end if;
      pos := array_position(anc_to, uids[k_i]);
      if pos is not null and array_length(uids, 1) - k_i > anc_to_d[pos]
         and coalesce(array_to_string(v_dirs[k_i:], ','), '') !~ '^down(,down)*$' then
        bad := true; exit;
      end if;
      pos := array_position(anc_to_sp, uids[k_i]);
      if v_dirs[array_length(v_dirs, 1)] = 'spouse' and pos is not null
         and array_length(uids, 1) - k_i > anc_to_sp_d[pos]
         and coalesce(array_to_string(v_dirs[k_i:array_length(v_dirs, 1) - 1], ','), '') !~ '^down(,down)*$' then
        bad := true; exit;
      end if;
    end loop;
    continue when bad;
    continue when uids && desc_both;

    -- a marriage step that only swaps one parent for the other is a detour:
    -- up to the mother then across to her husband (= just up to the father),
    -- or across to the father then down to his child by the same mother
    for k_i in 2 .. array_length(uids, 1) - 1 loop
      if v_dirs[k_i - 1] = 'up' and v_dirs[k_i] = 'spouse' and exists (
           select 1 from family_members fm join families f on f.uid = fm.family_uid
            where fm.person_uid = uids[k_i - 1] and fm.role = 'child'
              and (uids[k_i + 1] in (f.husband_uid, f.wife_uid)
                   or exists (select 1 from person_identity_members m1
                                join person_identity_members m2 on m2.group_id = m1.group_id
                               where m1.person_uid = uids[k_i + 1]
                                 and m2.person_uid in (f.husband_uid, f.wife_uid)))) then
        bad := true; exit;
      end if;
      if v_dirs[k_i - 1] = 'spouse' and v_dirs[k_i] = 'down' and exists (
           select 1 from family_members fm join families f on f.uid = fm.family_uid
            where fm.person_uid = uids[k_i + 1] and fm.role = 'child'
              and (uids[k_i - 1] in (f.husband_uid, f.wife_uid)
                   or exists (select 1 from person_identity_members m1
                                join person_identity_members m2 on m2.group_id = m1.group_id
                               where m1.person_uid = uids[k_i - 1]
                                 and m2.person_uid in (f.husband_uid, f.wife_uid)))) then
        bad := true; exit;
      end if;
    end loop;
    continue when bad;

    -- each record as its real person (identity-linked duplicates share one id)
    select array_agg(coalesce(g.gid, u.uid) order by u.i)
      into canon
      from unnest(uids) with ordinality u(uid, i)
      left join lateral (
        select min(mm.group_id::text) as gid
          from person_identity_members mm
         where mm.person_uid = u.uid
      ) g on true;
    continue when (select count(distinct x) from unnest(canon) x) < array_length(canon, 1);

    -- same route except for which spouse of a couple it peaks at: count once
    dedupe_key := array_to_string(v_dirs, ',') || '|' || (
      select string_agg(case when gi > 1 and gi < array_length(canon, 1)
                                  and v_dirs[gi - 1] = 'up' and v_dirs[gi] = 'down'
                             then '^' else canon[gi] end, '>' order by gi)
        from generate_subscripts(canon, 1) gi);
    continue when dedupe_key = any (seen);
    seen := seen || dedupe_key;

    select jsonb_agg(jsonb_build_object('uid', u.uid, 'name', p.name, 'sex', p.sex) order by u.i)
      into steps
      from unnest(uids) with ordinality u(uid, i)
      left join people p on p.uid = u.uid;

    -- classic shape [spouse] up* down* [spouse]? then also give up/down/... fields
    core := array_to_string(v_dirs, ',');
    fs := core like 'spouse%';
    ts := core like '%spouse' and core <> 'spouse';
    if core = 'spouse' then ts := true; fs := false; end if;
    core := regexp_replace(regexp_replace(core, '^spouse,?', ''), ',?spouse$', '');
    if core = '' or (core !~ 'spouse' and core ~ '^(up)?(,up)*,?(down)?(,down)*$') then
      n_up := (select count(*) from unnest(v_dirs) x where x = 'up');
      n_down := (select count(*) from unnest(v_dirs) x where x = 'down');
      routes := routes || jsonb_build_array(jsonb_build_object(
        'up', n_up, 'down', n_down, 'from_spouse', fs, 'to_spouse', ts,
        'first_father', coalesce(cand.father_first, true),
        'dirs', to_jsonb(v_dirs), 'segmented', false, 'path', steps));
    else
      routes := routes || jsonb_build_array(jsonb_build_object(
        'first_father', coalesce(cand.father_first, true),
        'dirs', to_jsonb(v_dirs), 'segmented', true, 'path', steps));
    end if;
    exit when jsonb_array_length(routes) >= lim;
  end loop;

  return routes;
end;
$$;

create or replace function public.akt_connection_path(p_from text, p_to text, p_max int default 4)
returns jsonb
language sql
volatile
security invoker
set search_path to 'public'
as $$
  select public.akt_connection_paths(p_from, p_to, p_max, 1) -> 0;
$$;

revoke all on function public.akt_connection_paths(text, text, int, int) from public, anon;
grant execute on function public.akt_connection_paths(text, text, int, int) to authenticated;
revoke all on function public.akt_connection_path(text, text, int) from public, anon;
grant execute on function public.akt_connection_path(text, text, int) to authenticated;
