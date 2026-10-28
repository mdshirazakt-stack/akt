-- Advanced people search (2026-10-28) — powers the "Advanced Search" drawer on
-- index.html: age range, marital status, gender, living/deceased, and
-- current / native (root) / birth place, combinable with an optional name.
--
-- PRIVACY (the site's published "Date of birth privacy" rule: DOBs are not
-- shown publicly):
--   * Results never include birth_date, age, mobile or email — only the same
--     columns the normal search table already shows.
--   * Age can only be searched in 5-year bands (min and max must be multiples
--     of 5, max > min). Bands can only be combined on 5-year boundaries, so no
--     sequence of searches can narrow a person down to a single birth year.
--     Enforced HERE, not just in the UI, since anyone can call the RPC.
--   * Age is computed from the 4-digit year in the free-text birth_date
--     (same rule as person.html's extractBirthYear) and only applies to living
--     people. Only ~3% of profiles have a birth year recorded, so an age search
--     finds only those.
--
-- SECURITY INVOKER: runs with the caller's own rights, so the existing
-- people/families RLS (approved visitors only) still decides who can search.
--
-- Marital status is derived from family records (people.marr_status is mostly
-- blank): any current marriage → 'Married'; else any marriage marked widowed,
-- or whose spouse is deceased → 'Widowed'; else any divorced/separated/former →
-- 'Divorced / separated'; no spouse in any family → 'No spouse recorded'
-- (which is NOT the same as never married — the record may just be missing).

-- Father's name (2026-10-28): from the person's parent family (role 'child'
-- in family_members → families.husband_uid). Looked up only for the rows on
-- the current page. Changing the return columns needs a DROP first.
-- Mother's name (2026-10-28): same parent family → families.wife_uid.
drop function if exists public.akt_advanced_search(jsonb);

create function public.akt_advanced_search(p jsonb)
returns table (
  uid text, name text, nickname text, sex text,
  root_place text, current_place text, death_flag boolean,
  gedcom_id uuid, is_contributor boolean, community_role text,
  marital_status text, father_name text, mother_name text, total_count bigint
)
language plpgsql
stable
security invoker
set search_path to 'public'
as $$
declare
  v_age_min  int  := nullif(p->>'age_min', '')::int;
  v_age_max  int  := nullif(p->>'age_max', '')::int;
  v_sex      text := nullif(p->>'sex', '');
  v_alive    text := coalesce(nullif(p->>'alive', ''), 'any');      -- any | living | deceased
  v_marital  text := nullif(p->>'marital', '');                     -- married | widowed | divorced | none
  v_current  text := nullif(trim(p->>'current_place'), '');
  v_root     text := nullif(trim(p->>'root_place'), '');
  v_birth    text := nullif(trim(p->>'birth_place'), '');
  v_name     text := nullif(trim(p->>'name'), '');
  v_limit    int  := least(greatest(coalesce(nullif(p->>'limit', '')::int, 25), 1), 50);
  v_offset   int  := greatest(coalesce(nullif(p->>'offset', '')::int, 0), 0);
  v_year     int  := extract(year from now() at time zone 'Asia/Kolkata')::int;
  v_tokens   text[];
begin
  -- ── Privacy guard on age: 5-year bands only ──
  if v_age_min is not null or v_age_max is not null then
    v_age_min := coalesce(v_age_min, 0);
    v_age_max := coalesce(v_age_max, 120);
    if v_age_min < 0 or v_age_max > 120 or v_age_min % 5 <> 0 or v_age_max % 5 <> 0 or v_age_max <= v_age_min then
      raise exception 'Age must be searched in 5-year steps (for example 30 to 35)';
    end if;
  end if;
  if v_sex is not null and v_sex not in ('M', 'F') then raise exception 'Invalid gender'; end if;
  if v_alive not in ('any', 'living', 'deceased') then raise exception 'Invalid living/deceased value'; end if;
  if v_marital is not null and v_marital not in ('married', 'widowed', 'divorced', 'none') then
    raise exception 'Invalid marital status';
  end if;
  if v_age_min is null and v_sex is null and v_alive = 'any' and v_marital is null
     and v_current is null and v_root is null and v_birth is null and v_name is null then
    raise exception 'Choose at least one search option';
  end if;

  -- Name: every word (2+ chars) must appear in the name or nickname.
  if v_name is not null then
    select array_agg(t) into v_tokens
      from regexp_split_to_table(lower(v_name), '\s+') t
     where length(t) >= 2;
  end if;

  return query
  with base as (
    select pe.*,
           substring(pe.birth_date from '\m(?:18|19|20)\d{2}\M')::int as birth_year
      from public.people pe
     where pe.name is not null and pe.name <> ''
       -- same junk-row exclusions as the normal search (index.html loadSearch)
       and pe.name not like '(%' and pe.name not like '[%' and pe.name not like ',%'
       and pe.name not like ';%' and pe.name not like '-%' and pe.name not like '+%'
       and pe.name not ilike '1%son%' and pe.name not ilike '1%daughter%'
       and (v_sex is null or pe.sex = v_sex)
       and (v_alive = 'any'
            or (v_alive = 'living'   and coalesce(pe.death_flag, false) = false)
            or (v_alive = 'deceased' and pe.death_flag = true))
       and (v_current is null or pe.current_place ilike '%' || v_current || '%')
       and (v_root    is null or pe.root_place    ilike '%' || v_root    || '%')
       and (v_birth   is null or pe.birth_place   ilike '%' || v_birth   || '%')
       and (v_tokens is null or not exists (
              select 1 from unnest(v_tokens) tok
               where lower(coalesce(pe.name, '') || ' ' || coalesce(pe.nickname, '')) not like '%' || tok || '%'))
  ),
  aged as (
    select b.* from base b
     where v_age_min is null
        or (coalesce(b.death_flag, false) = false
            and b.birth_year is not null
            and (v_year - b.birth_year) >= v_age_min
            and (v_year - b.birth_year) <  v_age_max)
  ),
  marital as (
    select a.*,
      (select case
                when count(*) = 0 then null      -- no spouse in any family
                when bool_or(lower(coalesce(f.marr_status, '')) not in ('divorced','separated','former','widowed')
                             and coalesce(sp.death_flag, false) = false) then 'Married'
                when bool_or(lower(coalesce(f.marr_status, '')) = 'widowed' or coalesce(sp.death_flag, false)) then 'Widowed'
                else 'Divorced / separated'
              end
         from public.families f
         left join public.people sp
           on sp.uid = case when f.husband_uid = a.uid then f.wife_uid else f.husband_uid end
        where (f.husband_uid = a.uid or f.wife_uid = a.uid)
          and f.husband_uid is not null and f.wife_uid is not null
      ) as m_status
      from aged a
  ),
  filtered as (
    select m.*, coalesce(m.m_status, 'No spouse recorded') as marital_label
      from marital m
     where v_marital is null
        or (v_marital = 'married'  and m.m_status = 'Married')
        or (v_marital = 'widowed'  and m.m_status = 'Widowed')
        or (v_marital = 'divorced' and m.m_status = 'Divorced / separated')
        or (v_marital = 'none'     and m.m_status is null)
  )
  , page as (
    select x.*, count(*) over () as total
      from filtered x
     order by x.name, x.uid
     limit v_limit offset v_offset
  )
  select pg.uid, pg.name, pg.nickname, pg.sex, pg.root_place, pg.current_place, pg.death_flag,
         pg.gedcom_id, pg.is_contributor, pg.community_role, pg.marital_label,
         (select fa.name
            from public.family_members fm
            join public.families fp on fp.uid = fm.family_uid
            join public.people fa on fa.uid = fp.husband_uid
           where fm.person_uid = pg.uid and fm.role = 'child'
           order by fa.name
           limit 1) as father_name,
         (select mo.name
            from public.family_members fm
            join public.families fp on fp.uid = fm.family_uid
            join public.people mo on mo.uid = fp.wife_uid
           where fm.person_uid = pg.uid and fm.role = 'child'
           order by mo.name
           limit 1) as mother_name,
         pg.total
    from page pg
   order by pg.name, pg.uid;
end;
$$;

revoke all on function public.akt_advanced_search(jsonb) from public, anon;
grant execute on function public.akt_advanced_search(jsonb) to authenticated;
